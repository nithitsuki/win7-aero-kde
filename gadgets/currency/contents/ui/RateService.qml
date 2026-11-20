// SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Rate backend for the Currency gadget.
//
// The Windows 7 gadget asked the "wlsrvc.WLServices" Windows Live COM object
// for quotes. That service no longer exists, so this port uses Frankfurter
// (https://frankfurter.dev, API at https://api.frankfurter.dev/v1), a free JSON
// API in front of the daily European Central Bank reference rates.
//
// Limits of that data source:
//  * the ECB publishes once per working day (around 16:00 CET). Rates do not
//    move intraday, are not updated on weekends or TARGET holidays, and a
//    "today" quote is really the previous working day's reference;
//  * only the currencies the ECB quotes are available (~30), not the long
//    list of exotic codes the old MSN service knew;
//  * it is a reference rate, not a trading rate: no spread, no fees.
//
// No plugin outside QtQuick is required; the requests use QML's
// XMLHttpRequest.

import QtQuick

QtObject {
    id: service

    // `from=USD` makes every entry in `rates` "units of that currency per one
    // US dollar", which is all the cross rate math below needs.
    readonly property string ratesUrl: "https://api.frankfurter.dev/v1/latest?from=USD"
    readonly property string currenciesUrl: "https://api.frankfurter.dev/v1/currencies"

    // Fallback display names, used until /currencies has been fetched once.
    // The old gadget shipped a similar table so the picker was usable before
    // its service answered.
    readonly property var fallbackCurrencies: ({
        "AUD": "Australian Dollar",
        "BGN": "Bulgarian Lev",
        "BRL": "Brazilian Real",
        "CAD": "Canadian Dollar",
        "CHF": "Swiss Franc",
        "CNY": "Chinese Yuan",
        "CZK": "Czech Koruna",
        "DKK": "Danish Krone",
        "EUR": "Euro",
        "GBP": "British Pound",
        "HKD": "Hong Kong Dollar",
        "HUF": "Hungarian Forint",
        "IDR": "Indonesian Rupiah",
        "ILS": "Israeli New Shekel",
        "INR": "Indian Rupee",
        "ISK": "Icelandic Krona",
        "JPY": "Japanese Yen",
        "KRW": "South Korean Won",
        "MXN": "Mexican Peso",
        "MYR": "Malaysian Ringgit",
        "NOK": "Norwegian Krone",
        "NZD": "New Zealand Dollar",
        "PHP": "Philippine Peso",
        "PLN": "Polish Zloty",
        "RON": "Romanian Leu",
        "SEK": "Swedish Krona",
        "SGD": "Singapore Dollar",
        "THB": "Thai Baht",
        "TRY": "Turkish Lira",
        "USD": "US Dollar",
        "ZAR": "South African Rand"
    })

    property string baseCode: "USD"
    property var rates: ({})
    property var currencies: ({})
    property bool loading: false
    property bool hasData: false
    property var lastUpdate: null      // Date of the last successful download
    property string dataDate: ""       // ISO date reported by Frankfurter
    property string lastError: ""

    signal refreshed()
    signal failed()

    // ------------------------------------------------------------------
    // Names
    // ------------------------------------------------------------------

    function currencyName(code) {
        if (currencies && currencies[code] !== undefined)
            return String(currencies[code]);
        if (fallbackCurrencies[code] !== undefined)
            return fallbackCurrencies[code];
        return String(code);
    }

    // Sorted list of { code, name } for the dropdown. The original sorted by
    // the localized name, which here is the English name in capitals.
    function currencyList() {
        var source = (currencies && Object.keys(currencies).length > 0)
                   ? currencies : fallbackCurrencies;
        var list = [];
        for (var code in source)
            list.push({ code: String(code), name: String(source[code]).toUpperCase() });
        list.sort(function (a, b) {
            return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0);
        });
        return list;
    }

    function hasRate(code) {
        return rates[code] !== undefined && isFinite(rates[code]);
    }

    // ------------------------------------------------------------------
    // Conversion
    // ------------------------------------------------------------------

    // Number of amount `from` expressed in `to`, or NaN when a rate is missing.
    function convert(amount, from, to) {
        if (!hasData || !hasRate(from) || !hasRate(to))
            return NaN;
        if (!isFinite(amount))
            return NaN;
        var value = amount * rates[to] / rates[from];
        return isFinite(value) ? value : NaN;
    }

    // Original gadget formatting: 3 decimals when docked, 5 when undocked.
    function format(amount, from, to, decimals) {
        var value = convert(amount, from, to);
        if (isNaN(value))
            return "";
        return value.toFixed(decimals);
    }

    // ------------------------------------------------------------------
    // Cache
    // ------------------------------------------------------------------

    function isFresh() {
        if (!hasData || lastUpdate === null)
            return false;
        var age = Date.now() - lastUpdate.getTime();
        return age >= 0 && age < 24 * 60 * 60 * 1000;
    }

    function cacheJson() {
        if (!hasData)
            return "";
        return JSON.stringify({
            base: baseCode,
            date: dataDate,
            rates: rates
        });
    }

    function restoreCache(text) {
        if (!text)
            return false;
        try {
            var cached = JSON.parse(text);
            if (!cached || !cached.rates)
                return false;
            var table = {};
            for (var code in cached.rates) {
                var value = Number(cached.rates[code]);
                if (isFinite(value) && value > 0)
                    table[code] = value;
            }
            var base = cached.base || "USD";
            table[base] = 1;
            if (Object.keys(table).length < 2)
                return false;
            baseCode = base;
            rates = table;
            dataDate = cached.date || "";
            hasData = true;
            return true;
        } catch (e) {
            return false;
        }
    }

    // ------------------------------------------------------------------
    // Network
    // ------------------------------------------------------------------

    function _get(url, callback) {
        var xhr = new XMLHttpRequest();
        var settled = false;

        function settle(error, text) {
            if (settled)
                return;
            settled = true;
            callback(error, text);
        }

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== 4)
                return;
            if (xhr.status >= 200 && xhr.status < 300)
                settle(null, xhr.responseText);
            else
                settle("HTTP " + xhr.status, null);
        };
        xhr.onerror = function () { settle("network error", null); };
        xhr.ontimeout = function () { settle("timeout", null); };

        try {
            xhr.open("GET", url);
            xhr.timeout = 20000;
            xhr.setRequestHeader("Accept", "application/json");
            xhr.send();
        } catch (e) {
            settle(String(e), null);
        }
    }

    // Downloads rates and the currency name table in parallel. A failure of
    // the name table alone is harmless; the fallback names stay in use.
    function refresh() {
        if (loading)
            return;
        loading = true;
        lastError = "";

        var pending = 2;
        var ratesOk = false;

        function step() {
            pending -= 1;
            if (pending > 0)
                return;
            loading = false;
            if (ratesOk)
                refreshed();
            else
                failed();
        }

        _get(ratesUrl, function (error, text) {
            if (error !== null) {
                lastError = error;
                step();
                return;
            }
            try {
                var data = JSON.parse(text);
                if (!data || !data.rates)
                    throw new Error("no rates in response");
                var table = {};
                for (var code in data.rates) {
                    var value = Number(data.rates[code]);
                    if (isFinite(value) && value > 0)
                        table[code] = value;
                }
                var base = data.base || "USD";
                table[base] = 1;
                if (Object.keys(table).length < 2)
                    throw new Error("empty rate table");
                baseCode = base;
                rates = table;
                dataDate = data.date || "";
                lastUpdate = new Date();
                hasData = true;
                ratesOk = true;
            } catch (e) {
                lastError = String(e);
            }
            step();
        });

        _get(currenciesUrl, function (error, text) {
            if (error === null) {
                try {
                    var names = JSON.parse(text);
                    if (names && typeof names === "object")
                        currencies = names;
                } catch (e) {
                    // Keep the fallback names.
                }
            }
            step();
        });
    }
}
