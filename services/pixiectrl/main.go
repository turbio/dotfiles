package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"path/filepath"
	"strconv"
	"os"
)

var (
	port = flag.Int("port", 4242, "Port to listen on")
	addr = flag.String("addr", "127.0.0.1", "Address to listen on")
	hosts = flag.String("hosts", "", "path to config dirs for each host as <MAC ADDRESS>/{bzImage, initrd, cmdline}")
)

func main() {
	flag.Parse()
	http.HandleFunc("/v1/boot/", bootReq)
	http.ListenAndServe(*addr+":"+strconv.Itoa(*port), nil)
}

func bootReq(w http.ResponseWriter, r *http.Request) {
	MAC := filepath.Base(r.URL.Path)
	log.Printf("Serving boot config for %s", MAC)

	_, err := os.Stat(*hosts+"/"+MAC)
	if err != nil {
		log.Printf("Host %s not found", MAC)
		http.Error(w, "Not Found", http.StatusNotFound)
		return
	}

	cmdline, err := os.ReadFile(*hosts+"/"+MAC+"/cmdline")
	if err != nil {
		panic(err)
	}

	resp := struct {
		Kernel string   `json:"kernel"`
		Initrd []string `json:"initrd"`
		Cmdline string  `json:"cmdline"`
		Message string  `json:"message"`
	}{
		Kernel: "file://"+*hosts+"/"+MAC+"/bzImage",
		Initrd: []string{
			"file://"+*hosts+"/"+MAC+"/initrd",
		},
		Cmdline: string(cmdline),
		Message: "heyo!",
	}

	if err := json.NewEncoder(w).Encode(&resp); err != nil {
		panic(err)
	}
}


