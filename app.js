var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);

http.setTimeout(10*60*1000);
http.listen(3000, function(){
	console.log('listening on *:3000');
});


var position = {};
position.gx = 300;
position.gy = 300;
position.ax = 400;
position.ay = 400;

mapx = 1273623389;
mapy = 363706170;

const exec = require('child_process').exec;

var signal = null;
var available = true;
var waiting = false;
var applied = true;
var elapsed_date;
var elapsed_time = 0;
function runCalculation(){
	var time_start = new Date().getTime();

	available = false;
	waiting = false;
	var prog = "./prog " + mapx + " " + mapy + " " + position.gx + " " + position.gy + " " + position.ax + " " + position.ay;
	exec(prog, (err, stdout, stderr) => {
		if (err) {
			console.error(err);
			return;
		}
		//console.log(stdout);
		signal = JSON.parse(stdout);
		//console.log(signal);
		console.log("[GPU] " + Date().toString());
		elapsed_date = new Date();
		elapsed_time = elapsed_date.getTime() - time_start;
		available = true;
		applied = false;
	});
}
runCalculation(); //initalize



app.use(express.static(__dirname));
app.get('/gamemap', function(req, res){res.sendFile(__dirname + '/gamemap.txt');});
app.get('/', function(req, res){res.sendFile(__dirname + '/index.html');});
app.get('/kaistmap.jpg', function(req, res){res.sendFile(__dirname + '/kaistmap.jpg');});

var running = false;
app.get('/download_map', function(req, res){
	if (!req.query.lat || !req.query.lon){
		res.redirect('/');
		res.end();
		return;
	}
	//if (running) return;
	running = true;
	var lat = parseFloat(req.query.lat);
	var lon = parseFloat(req.query.lon);
	mapy = parseInt(lat * 1e7);
	mapx = parseInt(lon * 1e7);

	var nprog = 'python map_crawling.py ' + lat + ' ' + lon;
	console.log("[app] " + nprog);
	exec(nprog, {timeout: 1000000}, (err, stdout, stderr) => {
		if (err) {
			console.error(err);
			return;
		}
		console.log("[app] python crawling complete.");
		console.log(stdout);

		running = false;

		res.redirect('/');
		res.end();
	});
});


var userData = {};
var playerNum = 0;
/*** Socket.io IO-CONNECTION ***/
io.on('connection', function(socket){
	console.log('[app] ' + socket.id + " is connected");
	socket.emit('init-client', {message: socket.id + " is connected"});
	userData[socket.id] = '';

	socket.on('select', function(data){
		//console.log(data);
		userData[socket.id] = data.mode;
		updatePosition();
	});

	function updatePosition(){
		if (!signal) return;
		for (var mid in userData){
			if (userData[mid] == 'A') 
				io.to(mid).emit('position-update', {pos: position, data: signal[1],
													elapsed: {date: elapsed_date.getTime(), time: elapsed_time}});
			if (userData[mid] == 'B') 
				io.to(mid).emit('position-update', {pos: position, data: signal[0],
													elapsed: {date: elapsed_date.getTime(), time: elapsed_time}});
		}
	}
	
	socket.on('disconnect', function(){
		//console.log('user disconnected');
		console.log('[app] ' + socket.id + " is disconnected");
		delete userData[socket.id];
		io.emit('user-data', userData);
	});
	
	socket.on('client-left', function(){
		if(userData[socket.id]== 'A') position.gx -= 5;
		if(userData[socket.id]== 'B') position.ax -= 5;
		//runCalculation();
		waiting = true;
		updatePosition()
	});
	socket.on('client-right', function(){
		if(userData[socket.id]== 'A') position.gx += 5;
		if(userData[socket.id]== 'B') position.ax += 5;
		//runCalculation();
		waiting = true;
		updatePosition()
	});
	socket.on('client-up', function(){
		if(userData[socket.id]== 'A') position.gy -= 5;
		if(userData[socket.id]== 'B') position.ay -= 5;
		//runCalculation();
		waiting = true;
		updatePosition()
	});
	socket.on('client-down', function(){
		if(userData[socket.id]== 'A') position.gy += 5;
		if(userData[socket.id]== 'B') position.ay += 5;
		//runCalculation();
		waiting = true;
		updatePosition()
	});
	socket.on('client-click', function(p){
		if(userData[socket.id]== 'A'){
			position.gx = p.x;
			position.gy = p.y;
		}
		if(userData[socket.id]== 'B'){
			position.ax = p.x;
			position.ay = p.y;
		}
		//runCalculation();
		waiting = true;
		updatePosition()
	});

	setInterval(function(){
		if(waiting && available){
			runCalculation();
		}
		if(!applied){
			updatePosition();
		}
	}, 100);
});

