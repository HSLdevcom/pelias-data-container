const request = require ("request");
const FeedParser = require ("feedparser");
const apiKey = process.env.MMLAPIKEY;
const feedUrl = "https://tiedostopalvelu.maanmittauslaitos.fi/tp/feed/mtp/nimisto/paikat?api_key=" + apiKey;

function getFeed (urlfeed, callback) {
  var req = request (urlfeed);
  var feedparser = new FeedParser ();
  var feedItems = new Array ();
  req.on ("response", function (response) {
    var stream = this;
    if (response.statusCode == 200) {
      stream.pipe (feedparser);
    }
  });
  req.on ("error", function (err) {
    console.log ("getFeed: err.message == " + err.message);
  });
  feedparser.on ("readable", function () {
    try {
      var item = this.read (), flnew;
      if (item !== null) {
        feedItems.push (item);
      }
    }
    catch (err) {
      console.log ("getFeed: err.message == " + err.message);
    }
  });
  feedparser.on ("end", function () {
    callback (undefined, feedItems);
  });
  feedparser.on ("error", function (err) {
    console.log ("getFeed: err.message == " + err.message);
    callback (err);
  });
}

getFeed (feedUrl, function (err, feedItems) {
  if (!err) {
    feedItems.sort( function(a, b) {
      if(a.date < b.date) return 1;
      else if (a.date > b.date) return -1;
      return 0;
    });
    console.log(feedItems[0].link);
  }
});


