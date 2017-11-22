var SCALE = 1;
var nodes = [];
var buildings = [];
var forests = [];
var amenity = [];
var water = [];
var roads = [];
var cx = 0;//1273623389;
var cy = 0;//363706170;
var ORTHO = 80000;
var width = 800;
var height = 800;
var userMode = '';
var w = window.innerWidth;
var h = window.innerHeight;
var map = null;


function initAutocomplete() {
	map = new google.maps.Map(document.getElementById('map'), {
	  zoom: 15,
	  center: {lng: 127.3623389, lat: 36.3706170},
	  mapTypeId: 'satellite'
	});
	// Create the search box and link it to the UI element.
	var input = document.getElementById('pac-input');
	var searchBox = new google.maps.places.SearchBox(input);
	map.controls[google.maps.ControlPosition.TOP_LEFT].push(input);

	// Bias the SearchBox results towards current map's viewport.
	map.addListener('bounds_changed', function() {
	  searchBox.setBounds(map.getBounds());
	  document.getElementById('lat-id').value = map.center.lat();
	  document.getElementById('lon-id').value = map.center.lng();
	});

	var markers = [];
	// Listen for the event fired when the user selects a prediction and retrieve
	// more details for that place.
	searchBox.addListener('places_changed', function() {
	  var places = searchBox.getPlaces();

	  if (places.length == 0) {
		return;
	  }

	  // Clear out the old markers.
	  markers.forEach(function(marker) {
		marker.setMap(null);
	  });
	  markers = [];

	  // For each place, get the icon, name and location.
	  var bounds = new google.maps.LatLngBounds();
	  places.forEach(function(place) {
		if (!place.geometry) {
		  console.log("Returned place contains no geometry");
		  return;
		}
		var icon = {
		  url: place.icon,
		  size: new google.maps.Size(71, 71),
		  origin: new google.maps.Point(0, 0),
		  anchor: new google.maps.Point(17, 34),
		  scaledSize: new google.maps.Size(25, 25)
		};

		// Create a marker for each place.
		markers.push(new google.maps.Marker({
		  map: map,
		  icon: icon,
		  title: place.name,
		  position: place.geometry.location
		}));

		if (place.geometry.viewport) {
		  // Only geocodes have viewport.
		  bounds.union(place.geometry.viewport);
		} else {
		  bounds.extend(place.geometry.location);
		}
	  });
	  map.fitBounds(bounds);
	});
  }

$(function(){
	SCALE = (h - 10) / 800;
	load_map();

	var app = new PIXI.Application(w - 10, h - 10);
	//document.body.appendChild(app.view);
	var myView = document.getElementById('myCanvas');
	myView.appendChild(app.view);
	
	var map_graphics = new PIXI.Graphics();
	var graphics = new PIXI.Graphics();
	
	app.stage.addChild(map_graphics);
	app.stage.addChild(graphics);
	app.renderer.backgroundColor = 0xDDDDDD;
	
	function load_map(){
		$.get( "/gamemap", function( data ) {
			var strArray = data.split('\n');
			for (var i in strArray){
				var str = strArray[i].trim();
				if (str[0] == '#') continue;
				if (str[0] == 'i') {
					var s = str.split('\t');
					cx = s[4];
					cy = s[5];
					console.log(s, cx, cy);
				}
				if (str[0] == 'n') {
					var s = str.split('\t');
					var lat = parseInt(s[1] * 10000000);
					var lon = parseInt(s[2] * 10000000);

					var mx = ((lon - cx) / ORTHO * width /2 + width / 2 ) * SCALE;
					var my = ((lat - cy) / ORTHO * height /2 + height / 2 ) * SCALE;

					map.setCenter(new google.maps.LatLng(s[1], s[2]));
					nodes.push({y: my, x: mx});
				}
				if (str[0] == 'b') {
					var s = str.split('\t');
					buildings.push({inodes:s.slice(1)});
				}
				if (str[0] == 'f') {
					var s = str.split('\t');
					forests.push({inodes:s.slice(1)});
				}
				if (str[0] == 'a') {
					var s = str.split('\t');
					amenity.push({inodes:s.slice(1)});
				}
				if (str[0] == 'w') {
					var s = str.split('\t');
					water.push({inodes:s.slice(1)});
				}
				if (str[0] == 'r') {
					var s = str.split('\t');
					roads.push({inodes:s.slice(1)});
				}
			}
			//console.log(nodes);
			//console.log(buildings);
			//console.log(forests);
			//console.log(amenity);
			draw_map();
		});
	}

	function draw_map(){
		// set a fill and line style
		// draw a shape
		console.log('draw_map');
		map_graphics.lineStyle(3, 0xCC3333, 1);
		for (var i in amenity){
			var x, y;
			var first = true;
			for (var j in amenity[i].inodes){
				map_graphics.beginFill(0xCCCCCC);
				var node = nodes[amenity[i].inodes[j]];
				if (first){
					first = false;
					map_graphics.moveTo(node.x, height *SCALE - node.y);
				}
				else{
					map_graphics.lineTo(node.x, height *SCALE - node.y);
				}
				map_graphics.endFill();
			}
		}
		// set a fill and line style
		// draw a shape
		map_graphics.lineStyle(0, 0xffd900, 1);
		for (var i in buildings){
			//console.log(buildings[i]);
			var x, y;
			var first = true;
			for (var j in buildings[i].inodes){
				map_graphics.beginFill(0xFF3300);
				//console.log(j);
				var node = nodes[buildings[i].inodes[j]];
				//console.log(buildings[i].inodes[j], node);
				//console.log(node);
				if (first){
					first = false;
					map_graphics.moveTo(node.x, height *SCALE - node.y);
				}
				else{
					map_graphics.lineTo(node.x, height *SCALE - node.y);
				}
				map_graphics.endFill();
			}
		}
		// set a fill and line style
		// draw a shape
		map_graphics.lineStyle(2, 0x119933, 1);
		for (var i in forests){
			var x, y;
			var first = true;
			for (var j in forests[i].inodes){
				map_graphics.beginFill(0x22BB44);
				var node = nodes[forests[i].inodes[j]];
				if (first){
					first = false;
					map_graphics.moveTo(node.x, height *SCALE - node.y);
				}
				else{
					map_graphics.lineTo(node.x, height *SCALE - node.y);
				}
				map_graphics.endFill();
			}
		}
		// set a fill and line style
		// draw a shape
		map_graphics.lineStyle(0);
		for (var i in water){
			var x, y;
			var first = true;
			for (var j in water[i].inodes){
				map_graphics.beginFill(0x8888BB);
				var node = nodes[water[i].inodes[j]];
				if (first){
					first = false;
					map_graphics.moveTo(node.x, height *SCALE - node.y);
				}
				else{
					map_graphics.lineTo(node.x, height *SCALE - node.y);
				}
				map_graphics.endFill();
			}
		}
		// set a fill and line style
		// draw a shape
		map_graphics.lineStyle(1, 0xCCAFAF, 1);
		for (var i in roads){
			var x, y;
			var first = true;
			for (var j in roads[i].inodes){
				var node = nodes[roads[i].inodes[j]];
				if (first){
					first = false;
					map_graphics.moveTo(node.x, height *SCALE - node.y);
				}
				else{
					map_graphics.lineTo(node.x, height *SCALE - node.y);
				}
			}
		}
	}

	var socket = io();
	socket.on('init-client', function(serverData){
		//alert(serverData.message);
	});

	var last_updated = null;
	var updated_html = '';
	setInterval(function(){
		if(!last_updated) return;
		
		var current = new Date().getTime() - last_updated;
		$('#breifing').html(updated_html + '<p>Updated ' + parseInt(current / 1000) + ' seconds ago</p>');
	}, 1000);
	
	socket.on('position-update', function(serverData){
		//console.log(serverData);
		var pos = serverData.pos;

		graphics.clear();
		var sig = serverData.data;
		//console.log(sig);
		//alert(serverData.message);
		//graphics.position.set(pos.ax, pos.ay);
		var elapsed = serverData.elapsed;
		//$('#breifing').html('<h5>' + elapsed.date + '</h5><h3>GPU Elapsed: ' + elapsed.time / 1000 + ' seconds</h3>');
		last_updated = elapsed.date;
		var dateStr = new Date(elapsed.date).toString();
		updated_html = '<h5>' + dateStr + '</h5><h3>GPU Elapsed: ' + elapsed.time / 1000 + ' seconds</h3>';
		
		if (userMode == 'B' || userMode == 'A' && check){
			graphics.lineStyle(0);
			graphics.beginFill(0x00FFFF, .5);
			graphics.drawCircle(pos.ax * SCALE, pos.ay * SCALE, 40);
		}
		if (userMode == 'A' || userMode == 'B' && check){
			graphics.lineStyle(0);
			graphics.beginFill(0x00FFFF, .5);
			graphics.drawCircle(pos.gx * SCALE, pos.gy * SCALE, 40);
		}

		for(var i = 0; i < sig.length; i++){
			//console.log(sig[i]);
			// Move it to the beginning of the line
			//graphics.position.set(pos.ax, pos.ay);
			var rad = i * Math.PI / 180;
			
			if(sig[i] == 0) continue;
			var tx = sig[i] * Math.cos(rad) / 1500;
			var ty = sig[i] * Math.sin(rad) / 1500;
			//glVertex3f(pos.ax + tx, pos.ay + ty, 0.0f);
			
			//graphics.position.set(pos.ax, pos.ay);
			// Draw the line (endPoint should be relative to myGraph's position)
			//console.log(tx, ty);

			if (userMode == 'A') {
				graphics.lineStyle(2, 0xff00ff)
					   .moveTo(pos.gx * SCALE, pos.gy * SCALE)
					   .lineTo(pos.gx * SCALE + tx, pos.gy * SCALE - ty);
			}
			if (userMode == 'B') {
				graphics.lineStyle(2, 0xff00ff)
					   .moveTo(pos.ax * SCALE, pos.ay * SCALE)
					   .lineTo(pos.ax * SCALE + tx, pos.ay * SCALE - ty);
			}
		}

		
		if (userMode == 'B' || userMode == 'A' && check){
			graphics.lineStyle(0);
			graphics.beginFill(0x0000FF, 1.0);
			graphics.drawCircle(pos.ax * SCALE, pos.ay * SCALE, 5);
		}
		if (userMode == 'A' || userMode == 'B' && check){
			graphics.lineStyle(0);
			graphics.beginFill(0xFF0000, 1.0);
			graphics.drawCircle(pos.gx * SCALE, pos.gy * SCALE, 5);
		}
	});
	
	$('#A').click(function(){
		userMode = 'A';
		socket.emit('select', {mode: 'A'});
		$('#A').addClass('btn-danger');
		$('#B').removeClass('btn-primary');
	});
	$('#B').click(function(){
		userMode = 'B';
		socket.emit('select', {mode: 'B'});
		$('#A').removeClass('btn-danger');
		$('#B').addClass('btn-primary');
	});
	var check = false;
	$('#C').click(function(){
		check = !check;
		if (check)
			$('#C').addClass('btn-warning');
		else 
			$('#C').removeClass('btn-warning');
	});
	
	$(document).on('keydown', function( event ) {
		var key = event.which || event.keyCode;
		if(key == 49)
		{
			userMode = 'A';
			socket.emit('select', {mode: 'A'});
			$('#A').addClass('btn-danger');
			$('#B').removeClass('btn-primary');
		}
		if(key == 50)
		{
			userMode = 'B';
			socket.emit('select', {mode: 'B'});
			$('#A').removeClass('btn-danger');
			$('#B').addClass('btn-primary');
		}
		if(userMode != 'A' && userMode != 'B') return;
		//console.log(key);
		
		if(key == '37')// || key == 65	) //left
		{
		  socket.emit('client-left');
		}
		if(key == '38')// || key == 87) //up
		{
		  socket.emit('client-up');
		}
		if(key == '39')// || key == 68) //right
		{
		  socket.emit('client-right');
		}
		if(key == '40')// || key == 83) //down
		{
		  socket.emit('client-down');
		}
		
	});

	$('#myCanvas').click(function (e) { //Relative ( to its parent) mouse position 
        //alert((e.pageX - w * 0.3) + ' , ' + (e.pageY));
		var kx = e.pageX - w*0.3 - 2, 
			ky = e.pageY - 2;
		kx /= SCALE;
		ky /= SCALE;
		socket.emit('client-click', {x:kx, y:ky});
    });


});


