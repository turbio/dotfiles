{ config, pkgs, lib, ... }:
let
  vibes_golang = (pkgs.writeTextDir "vibes.go" ''
        package main

    import (
      "flag"
      "fmt"
      "io/ioutil"
      "math/rand"
      "net/http"
      "os"
      "path"
      "strings"
    )

    var root string
    var mediaRoot string

    func isal(s string) bool {
      for _, r := range s {
        if r < 'a' || r > 'z' {
          return false
        }
      }
      return true
    }

    func next(w http.ResponseWriter, r *http.Request) {
      r.ParseForm()

      cat := r.Form.Get("cat")

      cats := strings.Split(cat, ",")

      tagset := map[string]bool{}

      for _, c := range cats {
        pos := true
        if len(c) > 0 && c[0] == '-' {
          c = c[1:]
          pos = false
        }

        if c == "" || !isal(c) {
          fmt.Println("bad cat", c)
          http.Error(w, "not a cat", http.StatusBadRequest)
          return
        }

        catdir := path.Join(root, "cat", c)

        ents, err := ioutil.ReadDir(catdir)
        if err != nil {
          fmt.Println("not a cat", err)
          http.Error(w, "not a cat", http.StatusBadRequest)
          return
        }

        for _, p := range ents {
          if pos {
            tagset[p.Name()] = true
          } else {
            tagset[p.Name()] = false
          }
        }
      }

      toarray := []string{}
      for a, v := range tagset {
        if v {
          toarray = append(toarray, a)
        }
      }

      if len(toarray) == 0 {
        http.Error(w, "no tags", http.StatusBadRequest)
        fmt.Println("no tags!")
        return
      }

      to := toarray[rand.Int()%len(toarray)]

      fmt.Fprintf(w, "/media/%s", to)
    }

    func cat(w http.ResponseWriter, r *http.Request) {
      r.ParseForm()

      vid := r.Form.Get("vid")
      cat := r.Form.Get("cat")

      if vid == "" || cat == "" || !isal(cat) {
        fmt.Println("vad vid/cat in cat")
        http.Error(w, "cant cat", http.StatusBadRequest)
        return
      }

      vid = path.Base(vid)

      if _, err := os.Stat(path.Join(root, "media", vid)); err != nil {
        fmt.Println("cant stat vid for cat", err)
        http.Error(w, "cant cat", http.StatusBadRequest)
        return
      }

      if _, err := os.Stat(path.Join(root, "cat", cat)); err != nil {
        fmt.Println("cant stat cat", err)
        http.Error(w, "cant cat", http.StatusBadRequest)
        return
      }

      if err := os.Symlink(path.Join(root, "media", vid), path.Join(root, "cat", cat, vid)); err != nil {
        fmt.Println("cant link cat", err)
        http.Error(w, "cant cat", http.StatusBadRequest)
        return
      }
    }

    func index(w http.ResponseWriter, r *http.Request) {
      w.Write([]byte(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>vibes</title>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
    body {
      margin: 0;
    }
    #vid {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    #c {
      overflow: hidden;
      width: 100vw;
      height: 100vh;
    }

    #cats {
      position: absolute;
      bottom: 0;
      right: 0;
      display: flex;
    }

    #cats > div {
      cursor: pointer;
      padding: 0.25em;
    }

    #cats > div:hover {
      filter: brightness(1.5);
    }

    #pbtn {
      font-size: 50vw;
      display: none;
      position: absolute;
      left: 0;
      right: 0;
      top: 0;
      bottom: 0;
      align-items: center;
      justify-content: center;
      cursor: pointer;
    }
      </style>
    </head>
    <body>
      <div id="c" class="crt">
        <video class="screen" id="vid" autoplay></video>
        <div class="overlay" id="name">AV-1</div>
        <div id="pbtn">&blacktriangleright;</div>
      </div>
      <div id="cats">
        <div class="cat" cat="bop">👍</div>
        <div class="cat" cat="flop">👎</div>
        <div class="cat" cat="anime">🌸</div>
        <div class="cat" cat="lewd">🍆</div>
      </div>

      <script>
    const vid = document.getElementById('vid');
    let cat;

    if (location.search.startsWith('?cat=')) {
      cat = location.search.slice(5);
    } else {
      cat = "bop,-flop,-lewd";
    }

    let cvid = "";

    vid.play()
      .then(() => {})
      .catch(err => {
        console.log("cant play", err);
        document.getElementById('pbtn').style.display = "flex";
        document.getElementById('pbtn').onclick = () => {
          vid.play();
          document.getElementById('pbtn').style.display = "none";
        };
      });

    async function setcat(cat) {
      const r = await fetch("/c/cat?cat="+cat+"&vid="+cvid);
      console.log(r);
    }

    [...document.getElementsByClassName('cat')]
      .forEach(e => {
        console.log(e);
        e.addEventListener('click', () => {
          setcat(e.attributes.cat.value);
          if (e.attributes.cat.value == 'flop') {
            loadnext();
          }
        })
      });

    async function loadnext() {
      const r = await fetch("/c/next?cat="+cat);
      console.log(r.status)
      if (r.status !== 200) {
        console.log('ohno', r);
        return
      }
      const n = await r.text();
      console.log(n);

      document.getElementById('name').textContent = 'AV-' + n
        .split('/').slice(-1).join()
        .split('.')[0]
        .slice(-5);
      document.getElementById('name').style.animation = 'none';
      document.getElementById('name').offsetHeight;
      document.getElementById('name').style.animation = null;

      cvid = n;
      vid.src = n;
    }

    vid.ended = loadnext;
    vid.addEventListener('ended', () => loadnext());

    loadnext();
      </script>
      <style>
    body {
      background: #111;
      color: white;
    }

    @keyframes flicker {
      0% {
        opacity: 0.53073;
      }
      5% {
        opacity: 0.46322;
      }
      10% {
        opacity: 0.48857;
      }
      15% {
        opacity: 0.56716;
      }
      20% {
        opacity: 0.9877;
      }
      25% {
        opacity: 0.72939;
      }
      30% {
        opacity: 0.13295;
      }
      35% {
        opacity: 0.82697;
      }
      40% {
        opacity: 0.87107;
      }
      45% {
        opacity: 0.07205;
      }
      50% {
        opacity: 0.30767;
      }
      55% {
        opacity: 0.89503;
      }
      60% {
        opacity: 0.99178;
      }
      65% {
        opacity: 0.38725;
      }
      70% {
        opacity: 0.85501;
      }
      75% {
        opacity: 0.54748;
      }
      80% {
        opacity: 0.6573;
      }
      85% {
        opacity: 0.7574;
      }
      90% {
        opacity: 0.02935;
      }
      95% {
        opacity: 0.17227;
      }
      100% {
        opacity: 0.84228;
      }
    }
    .crt {
      background: #121010;
      position: relative;
    }
    .crt::after {
      content: " ";
      display: block;
      position: absolute;
      top: 0;
      left: 0;
      bottom: 0;
      right: 0;
      background: rgba(18, 16, 16, 0.1);
      opacity: 0;
      z-index: 2;
      pointer-events: none;
    }
    .crt::before {
      content: " ";
      display: block;
      position: absolute;
      top: 0;
      left: 0;
      bottom: 0;
      right: 0;
      background: linear-gradient(rgba(18, 16, 16, 0) 50%, rgba(0, 0, 0, 0.25) 50%), linear-gradient(90deg, rgba(255, 0, 0, 0.06), rgba(0, 255, 0, 0.02), rgba(0, 0, 255, 0.06));
      z-index: 2;
      background-size: 100% 2px, 3px 100%;
      pointer-events: none;
    }

    .crt::after {
      animation: flicker 0.15s infinite;
    }

    @keyframes turn-on {
      0% {
        transform: scale(1, 0.8) translate3d(0, 0, 0);
        -webkit-filter: brightness(30);
        filter: brightness(30);
        opacity: 1;
      }
      3.5% {
        transform: scale(1, 0.8) translate3d(0, 100%, 0);
      }
      3.6% {
        transform: scale(1, 0.8) translate3d(0, -100%, 0);
        opacity: 1;
      }
      9% {
        transform: scale(1.3, 0.6) translate3d(0, 100%, 0);
        -webkit-filter: brightness(30);
        filter: brightness(30);
        opacity: 0;
      }
      11% {
        transform: scale(1, 1) translate3d(0, 0, 0);
        -webkit-filter: contrast(0) brightness(0);
        filter: contrast(0) brightness(0);
        opacity: 0;
      }
      100% {
        transform: scale(1, 1) translate3d(0, 0, 0);
        -webkit-filter: contrast(1) brightness(1.2) saturate(1.3);
        filter: contrast(1) brightness(1.2) saturate(1.3);
        opacity: 1;
      }
    }
    @keyframes turn-off {
      0% {
        transform: scale(1, 1.3) translate3d(0, 0, 0);
        -webkit-filter: brightness(1);
        filter: brightness(1);
        opacity: 1;
      }
      60% {
        transform: scale(1.3, 0.001) translate3d(0, 0, 0);
        -webkit-filter: brightness(10);
        filter: brightness(10);
      }
      100% {
        animation-timing-function: cubic-bezier(0.755, 0.05, 0.855, 0.06);
        transform: scale(0, 0.0001) translate3d(0, 0, 0);
        -webkit-filter: brightness(50);
        filter: brightness(50);
      }
    }
    .screen {
      width: 100%;
      height: 100%;
      border: none;
    }

    .crt > .screen {
      animation: turn-off 0.55s cubic-bezier(0.23, 1, 0.32, 1);
      animation-fill-mode: forwards;
    }

    .crt > .screen {
      animation: turn-on 4s linear;
      animation-fill-mode: forwards;
    }

    @keyframes overlay-anim {
      0% {
        visibility: hidden;
      }
      20% {
        visibility: hidden;
      }
      21% {
        visibility: visible;
      }
      100% {
        visibility: hidden;
      }
    }
    .overlay {
      color: #00FF00;
      position: absolute;
      top: 20px;
      left: 20px;
      font-size: 60px;
      visibility: hidden;
      pointer-events: none;
      font-family: sans-serif;
    }

    .crt .overlay {
      animation: overlay-anim 5s linear;
      animation-fill-mode: forwards;
    }
      </style>
    </body>
    </html>
    `))
    }

    func main() {
      var addr = flag.String("addr", ":8080", "address to listen on")
      flag.StringVar(&root, "root", ".", "where to serve stuff from")

      flag.Parse()

      mediaRoot = path.Join(root, "media")

      http.Handle("/media/", http.StripPrefix("/media/", http.FileServer(http.Dir(mediaRoot))))
      http.HandleFunc("/c/next", next)
      http.HandleFunc("/c/cat", cat)
      http.HandleFunc("/", index)

      http.ListenAndServe(*addr, nil)
    }
  '');

  vibesbin = pkgs.buildGoPackage {
    name = "vibes";
    version = "0.0.1";
    src = vibes_golang;
    goPackagePath = "github.com/turbio/vibes";
  };

  content = "/vibes";
  port = "3010";
in
{
  system.activationScripts = {
    vibes = ''
      mkdir -p ${content}/media
      mkdir -p ${content}/cat/bop
      mkdir -p ${content}/cat/flop
      mkdir -p ${content}/cat/lewd
    '';
  };

  services.nginx.virtualHosts."vibes.turb.io" = {
    addSSL = true;
    enableACME = true;

    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString port}";
    };

    extraConfig = ''
      charset utf-8;
    '';
  };

  systemd.services.vibes = {
    description = "just vibin";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${vibesbin}/bin/vibes --addr 127.0.0.1:${builtins.toString port} --root ${content}";
    };
  };
}
