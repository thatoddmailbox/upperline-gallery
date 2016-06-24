var system = require('system');
var page = require('webpage').create();
var fs = require('fs');
var args = system.args;

if (!fs.exists("public/screenshots/")) {
	fs.makeDirectory("public/screenshots/");
}

page.viewportSize = { width: 800, height: 600 };
page.clipRect = {
	top:    0,
	left:   0,
	width:  800,
	height: 600
};
page.open(args[2], function(status) {
	console.log("Status: " + status);
	if (status === "success") {
		page.render("public/screenshots/" + args[1] + ".png");
	} else {
		fs.copy("public/fail.png", "public/screenshots/" + args[1] + ".png");
	}
	phantom.exit();
});
