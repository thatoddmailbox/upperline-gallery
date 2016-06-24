var system = require('system');
var page = require('webpage').create();
var fs = require('fs');
var args = system.args;

if (!fs.exists("public/screenshots/")) {
	fs.makeDirectory("public/screenshots/");
}

page.onResourceRequested = function (request) {
    system.stderr.writeLine('= onResourceRequested()');
    system.stderr.writeLine('  request: ' + JSON.stringify(request, undefined, 4));
};

page.onResourceReceived = function(response) {
    system.stderr.writeLine('= onResourceReceived()' );
    system.stderr.writeLine('  id: ' + response.id + ', stage: "' + response.stage + '", response: ' + JSON.stringify(response));
};

page.onLoadStarted = function() {
    system.stderr.writeLine('= onLoadStarted()');
    var currentUrl = page.evaluate(function() {
        return window.location.href;
    });
    system.stderr.writeLine('  leaving url: ' + currentUrl);
};

page.onLoadFinished = function(status) {
    system.stderr.writeLine('= onLoadFinished()');
    system.stderr.writeLine('  status: ' + status);
};

page.onNavigationRequested = function(url, type, willNavigate, main) {
    system.stderr.writeLine('= onNavigationRequested');
    system.stderr.writeLine('  destination_url: ' + url);
    system.stderr.writeLine('  type (cause): ' + type);
    system.stderr.writeLine('  will navigate: ' + willNavigate);
    system.stderr.writeLine('  from page\'s main frame: ' + main);
};

page.onResourceError = function(resourceError) {
    system.stderr.writeLine('= onResourceError()');
    system.stderr.writeLine('  - unable to load url: "' + resourceError.url + '"');
    system.stderr.writeLine('  - error code: ' + resourceError.errorCode + ', description: ' + resourceError.errorString );
};

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
	}
	phantom.exit();
});
