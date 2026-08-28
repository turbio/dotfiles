package main

import (
	"log"
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

	log.Println("requested video in cat", cats)

	tagset := map[string]bool{}

	for _, c := range cats {
		pos := true

		if len(c) > 0 && c[0] == '-' {
			c = c[1:]
			pos = false
		}

		if c == "" || !isal(c) {
			log.Println("bad cat", c)
			http.Error(w, "not a cat", http.StatusBadRequest)
			return
		}

		catdir := path.Join(root, "cat", c)

		ents, err := ioutil.ReadDir(catdir)
		if err != nil {
			log.Println("not a cat", err)
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
		log.Println("no tags!")
		return
	}

	to := toarray[rand.Int()%len(toarray)]

	fmt.Fprintf(w, "/media/%s", to)
}

func cat(w http.ResponseWriter, r *http.Request) {
	r.ParseForm()

	vid := r.Form.Get("vid")
	cat := r.Form.Get("cat")

	log.Println("tagging", vid, "with", cat)

	if vid == "" || cat == "" || !isal(cat) {
		log.Println("bad vid/cat in cat")
		http.Error(w, "cant cat", http.StatusBadRequest)
		return
	}

	vid = path.Base(vid)

	if _, err := os.Stat(path.Join(root, "media", vid)); err != nil {
		log.Println("cant stat vid for cat", err)
		http.Error(w, "cant cat", http.StatusBadRequest)
		return
	}

	if _, err := os.Stat(path.Join(root, "cat", cat)); err != nil {
		log.Println("cant stat cat", err)
		http.Error(w, "cant cat", http.StatusBadRequest)
		return
	}

	if err := os.Symlink(path.Join(root, "media", vid), path.Join(root, "cat", cat, vid)); err != nil {
		log.Println("cant link cat", err)
		http.Error(w, "cant cat", http.StatusBadRequest)
		return
	}
}

func main() {
	var addr = flag.String("addr", ":8080", "address to listen on")
	flag.StringVar(&root, "root", ".", "where to serve stuff from")

	flag.Parse()

	http.HandleFunc("/c/next", next)
	http.HandleFunc("/c/cat", cat)

	http.ListenAndServe(*addr, nil)
}
