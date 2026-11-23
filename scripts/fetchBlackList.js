const axios = require('axios');
const fs = require('fs');
const confPath = '/root/pelias.json'; // conf path in docker container
const data = fs.readFileSync(confPath);
const config = JSON.parse(data);
const {parse} = require('csv-parse/sync');
let url = config.imports.blacklistUrl;

// The blob container may require a SAS token (env variable or BuildKit secret)
function blobSas() {
  let sas = process.env.BLOB_SAS;
  if (!sas && fs.existsSync('/run/secrets/BLOB_SAS')) {
    sas = fs.readFileSync('/run/secrets/BLOB_SAS', 'utf8');
  }
  return sas ? sas.trim().replace(/^\?/, '') : '';
}
if (url && url.includes('.blob.core.windows.net/') && blobSas()) {
  url += '?' + blobSas();
}

if(url) {
  if (!config.imports.blacklist) {
    config.imports.blacklist = [];
  }
  console.log('Fetching blacklist from ' + url.split('?')[0]);
  axios.get(url, { timeout: 30000 })
    .then(function (response) {
      const rows = parse(response.data, {
	trim: true,
	delimiter: ',',
	relax_column_count: true,
	skip_empty_lines: true
      })
      rows.forEach(row => {
	config.imports.blacklist.push(row[0]);
      });
      fs.writeFileSync(confPath, JSON.stringify(config, null, 2), 'utf8');
      console.log('Blacklist updated');
    }).catch(err => {
      // the error object would include the request URL with the SAS token
      console.error('Fetching blacklist failed: ' + err.message);
      process.exitCode = 1;
    })
}
