var path = require('path');
var express = require('express');
var compression = require('compression');
var fs = require('fs');

var app = express();
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'hjs');
app.use(compression());
app.use(express.static(path.join(__dirname, 'public'), { maxAge: 31536000000 }));

app.listen(process.env.PORT || 3000, function(){
  console.log("Node app is running. Better go catch it.".green);
  if (typeof process.env.PUSHBULLETAUTH !== 'undefined') {
    // Don't send notifications when testing locally
    pusher.note(pushDeviceID, 'Server Restart');
  }
});

var numNodes = 3;
var currentNode = 1;

app.get('/', function(req, res) {
  return res.render('index');
});

app.get('/Ask', function(req, res) {
	return res.send(currentNode);
});

app.get('/Set', function(req, res) {
	var currentNode = req.query.newNode;
	return res.send(currentNode);
});