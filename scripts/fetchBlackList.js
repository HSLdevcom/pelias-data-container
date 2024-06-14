const axios = require('axios');
const fs = require('fs');
const confPath = '/root/pelias.json'; // conf path in docker container
const data = fs.readFileSync(confPath);
const config = JSON.parse(data);
const {parse} = require('csv-parse/sync');
const url = config.imports.blacklistUrl;

if(url && fs.existsSync(confPath)) {
  if (!config.imports.blacklist) {
    config.imports.blacklist = [];
  }
  console.log('Fetching blacklist from ' + url);
  axios.get(url)
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
      console.error(err);
    })
}
