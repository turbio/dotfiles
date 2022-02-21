use std::net::UdpSocket;
use std::str;
use std::fs::OpenOptions;
use std::io::Write;

fn main() {
    let mut file = OpenOptions::new()
        .append(true)
        .open("/var/gpslog")
        .unwrap();

    let mut socket = UdpSocket::bind("0.0.0.0:6969").expect("unable to bind");

    let mut buf = [0; 40960];
    loop {
        let sock = socket.try_clone().expect("unable to try close");

        match socket.recv_from(&mut buf) {
            Ok((amt, src)) => {
                let msg = str::from_utf8(&buf[..amt]).unwrap();
                write!(file, "{}", msg).expect("unable to write gpslog");


                // let parts: Vec<&str> = msg.split(",").collect();

                // if parts[0] != "$GPRMC" {
                //     println!("expected $GPRMC header, msg: {}", msg);
                //     break;
                // }

                // let utc = parts[1];
                // let status = parts[2];

                // let lat = parts[3];
                // let lat_dir = parts[4];

                // let lon = parts[5];
                // let lon_dir = parts[6];

                // let speed = parts[7];
                // let date = parts[9];

                // if status == "A" {
                //     // oki doki
                // } else if status == "V" {
                //     println!("status: not available");
                //     break;
                // } else {
                //     println!("unexpected status: {}", msg);
                //     break;
                // }

                // println!("utc {} {}", utc, date);
                // println!("lat {} {}", lat_dir, lat);
                // println!("lon {} {}", lon_dir, lon);
                // println!("speed {}", speed);
            }
            Err(err) => {
                eprintln!("err: {}", err);
            }
        }
    }
}
