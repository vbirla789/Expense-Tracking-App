/**
 * Expenses — Google Apps Script backend (deployed as a Web App).
 *
 * Setup:
 *  1. Create a Google Sheet with headers in row 1:
 *       id | timestamp | amount | merchant | category | source | raw
 *  2. Extensions > Apps Script, paste this in.
 *  3. Set SECRET below to your own long random string (same value goes in the app's Settings).
 *  4. Deploy > New deployment > Web app: Execute as Me, Who has access: Anyone.
 *     To update later: Deploy > Manage deployments > edit > Version: New version (keeps the URL).
 *
 * Supported POST actions: add (default), update (amount and/or category), delete.
 */

var SECRET = 'YOUR_SECRET_HERE';
var SHEET_NAME = 'Sheet1';
var HEADERS = ['id', 'timestamp', 'amount', 'merchant', 'category', 'source', 'raw'];

function sheet_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sh = ss.getSheetByName(SHEET_NAME) || ss.getSheets()[0];
  if (sh.getLastRow() === 0) sh.appendRow(HEADERS);
  return sh;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function rows_() {
  var sh = sheet_(), values = sh.getDataRange().getValues(), out = [];
  for (var i = 1; i < values.length; i++) {
    var r = values[i];
    if (!r[0] && !r[2]) continue;
    out.push({
      id: String(r[0]),
      timestamp: r[1] instanceof Date ? r[1].toISOString() : String(r[1]),
      amount: Number(r[2]) || 0, merchant: String(r[3] || ''),
      category: String(r[4] || 'Uncategorized'), source: String(r[5] || ''), raw: String(r[6] || '')
    });
  }
  return out;
}

function doGet(e) {
  var p = (e && e.parameter) || {};
  if (p.token !== SECRET) return json_({ ok: false, error: 'bad token' });
  return json_({ ok: true, transactions: rows_() });
}

function doPost(e) {
  var body = {};
  try { body = JSON.parse(e.postData.contents); } catch (err) {}
  if (body.token !== SECRET) return json_({ ok: false, error: 'bad token' });
  var sh = sheet_(), data = sh.getDataRange().getValues();

  if (body.action === 'delete') {
    for (var i = 1; i < data.length; i++) {
      if (String(data[i][0]) === String(body.id)) { sh.deleteRow(i + 1); return json_({ ok: true, deleted: body.id }); }
    }
    return json_({ ok: false, error: 'id not found' });
  }
  if (body.action === 'update') {
    for (var i = 1; i < data.length; i++) {
      if (String(data[i][0]) === String(body.id)) {
        if (body.category !== undefined && body.category !== null) sh.getRange(i + 1, 5).setValue(body.category);
        if (body.amount !== undefined && body.amount !== null && body.amount !== '') sh.getRange(i + 1, 3).setValue(Number(body.amount));
        return json_({ ok: true, id: body.id });
      }
    }
    return json_({ ok: false, error: 'id not found' });
  }
  var id = Utilities.getUuid(), ts = body.timestamp || new Date().toISOString();
  sh.appendRow([id, ts, Number(body.amount) || 0, body.merchant || '', body.category || 'Uncategorized', body.source || 'shortcut', body.raw || '']);
  return json_({ ok: true, id: id });
}
