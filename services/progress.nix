{ pkgs, ... }:
let
  index = pkgs.writeTextDir "root/index.html" ''
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width">
        <title>repl.it</title>
        <link href="style.css" rel="stylesheet" type="text/css" />
      </head>
      <body>
        <script src="script.js"></script>
      </body>
    </html>'';

  style = pkgs.writeTextDir "root/style.css" ''
    body {
    	line-height: 0;
    }

    .day {
    	background: #ccc;
    	width: 5px;
    	height: 5px;
    	display: inline-block;
    	margin: 1px;
    	padding: 0;
    }

    .done {
    	background: #888;
    }

    .year {
    	width: 10em;

    	display: inline-block;
    	margin: 2px;
    }

    .decade-label {
    	display: inline-block;
    	font-size: 3em;
    }
  '';

  script = pkgs.writeTextDir "root/script.js" ''
    const total = 365 * 85;
    const since = Math.round(
    	(new Date() - new Date('07/12/1997')) / (1000*60*60*24),
    );

    function make() {
    	let days = 0;
    	for (let dd = 0; dd < 9; dd++) {
    		const decade = document.createElement('div');
    		decade.classList.add('decade')
    		document.body.appendChild(decade)

    		for (let y = 0; y < 10; y++) {
    			const year = document.createElement('div');
    			year.classList.add('year')
    			decade.appendChild(year)

    			for (let d = 0; d < 365; d++) {
    				days++;
    				if (days > total) {
    					return
    				}

    				const day = document.createElement('div')
    				day.classList.add('day')

    				if (days < since) {
    					day.classList.add('done')
    				}

    				if (days > 365 * 75){
    					day.style.opacity = 1 - ((days - (365 * 75)) / (total - (365 * 75)));
    				}

    				year.appendChild(day);
    			}
    		}

    		const label = document.createElement('div')
    		label.className = 'decade-label';
    		label.innerHTML = days / 365;
    		decade.appendChild(label)
    	}
    }

    make();
  '';

  webroot = pkgs.buildEnv {
    name = "progress-webroot";
    paths = [
      index
      style
      script
    ];
  };
in
{
  services.nginx.virtualHosts."progress.turb.io" = {
    addSSL = true;
    enableACME = true;

    root = "${webroot}/root";

    locations."/" = {
      #tryFiles = "$uri /index.html";
    };

    extraConfig = ''
      charset utf-8;
    '';
  };
}
