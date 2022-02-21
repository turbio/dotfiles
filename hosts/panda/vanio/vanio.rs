//#[macro_use] extern crate rocket;

use std::io;
use std::fs::File;
use std::fs::OpenOptions;
use std::net::TcpListener;
use std::io::{Read, Write};
use std::net::Shutdown;
use std::io::BufRead;

use std::{
    collections::HashMap,
    sync::{Mutex, Arc},
};


//use std::net::UdpSocket;
use std::str;
//use std::fs::OpenOptions;
//use std::io::Write;
use std::thread;


const ASCII_VAN: &str = r#"

  :'''''''''':''''''''''''''''''':''''''''''':
.---------------------------------------------.
|   ..................---------------.  .      '.
|   .                 |               | . .----. '.
|   .                 |               | . :     '. '.
|   .                 |               | . :       '. :
|   .                 |               | . '.        : :
|    .................----------------' .   ''''''''   '.
/| ==================-.             -=- . -=-            '---_ 
||                    .                 .                     '-.
/                     .                 .                        '.
|...........__---__....................................__---__....|
|......... /.     .\................................../.     .\....| \
 '........|.   O   .|________________________________|.   O   .|...|_|
           :       :                                  :       :
            '-._.-'                                    '-._.-'
"#;

//#[get("/metrics")]
//fn index() -> &'static str {
//    "Hello, world!"
//}
//
//#[get("/")]
//fn index() -> &'static str {
//    "heyo!"
//}

fn prom_exporter(stats: Arc<Mutex<HashMap<String, f64>>>) {
    let listener = TcpListener::bind("127.0.0.1:9093").unwrap();
    println!("listening...");

    for stream in listener.incoming() {
        match stream {
            Ok(mut stream) => {
                let stats = stats.clone();
                thread::spawn(move || {
                    let mut res = "HTTP/1.1 200 OK\r
Content-Type: text/html; charset=UTF-8\r
\r
".to_string();
                    {
                        let stats = stats.lock().unwrap();
                        for (k, v) in stats.iter() {
                            res += &format!("{} {}\n", k, v);
                        }
                    }

                    match stream.write(res.as_bytes()) {
                        Ok(_) => println!("Response sent"),
                        Err(e) => println!("Failed sending response: {}", e),
                    }

                    stream.shutdown(Shutdown::Both);
                });
            }
            Err(e) => {
                println!("Unable to connect: {}", e);
            }
        }
    }
}

// const TARGET_TEMP: f64 = 73.0;
const TARGET_TEMP: f64 = 1.0;

fn main() {
    let mut temp_samps: HashMap<String, Vec<f64>> = HashMap::new();

    let prom_stats = Arc::new(Mutex::new(HashMap::new()));

    {
        let prom_stats = prom_stats.clone();
        thread::spawn(|| {
            prom_exporter(prom_stats);
        });
    }

    let mut arduino_tty = OpenOptions::new()
      .read(true)
      .write(true)
      .open("/dev/serial/by-id/usb-Arduino_LLC_Arduino_Leonardo-if00").unwrap();
    let mut liner = io::BufReader::new(arduino_tty.try_clone().unwrap());

    loop {

        let mut line = String::new();
        let len = liner.read_line(&mut line).unwrap();

        //let mut buf = [0; 1024];
        //let len = arduino_tty.read(&mut buf).unwrap();

        //let line = str::from_utf8(&buf[..len]).unwrap();
        let parts = line.split(" ").collect::<Vec<&str>>();

        //println!("a> {:?}", line);

        if parts.len() < 3 {
            continue;
        }

        if parts[0] != "stat" {
            println!("msg> {:?}", line);
            continue;
        }

        let key = parts[1].to_string();
        let val = parts[2].strip_suffix("\n").unwrap().strip_suffix("\r").unwrap().parse::<f64>().unwrap();

        {
          let mut st = prom_stats.lock().unwrap();
          st.insert(key.clone(), val);
        }

        // w buff of 1 deg

        if key == "ceiling_temp" {
          let temp = val;
          if temp > TARGET_TEMP+1.0 {
            arduino_tty.write_all(b"set fan off\n").unwrap();
            {
              let mut st = prom_stats.lock().unwrap();
              st.insert("fan".to_string(), 0.0);
            }
          } else {

            let diff = TARGET_TEMP - temp;
            let speed: u8 = if diff > 10.0 {
              255
            } else {
              (diff * 255.0 / 10.0) as u8
            };

            arduino_tty.write_all(b"set fan on\n").unwrap();
            arduino_tty.write_all(format!("set fanspeed {}\n", speed).as_bytes()).unwrap();
            {
              let mut st = prom_stats.lock().unwrap();
              st.insert("fan".to_string(), 1.0);
              st.insert("fanspeed".to_string(), speed as f64);
            }
          }
        }
    }
}
