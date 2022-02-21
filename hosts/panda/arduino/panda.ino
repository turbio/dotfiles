#include <DHT.h>
#include <Adafruit_SCD30.h>

#include <SPI.h>
#include <mcp_can.h>

#define FAN_PWM 9
#define FAN_ENABLE 10

Adafruit_SCD30  scd30;

DHT ceiling_temp(7, DHT11);
DHT floor_temp(8, DHT11);

MCP_CAN CAN0(23);

float ctof(float c) { return c * 1.8 + 32; }

void setup() {
  if (!scd30.begin()) {
    //ohno
  }

  scd30.selfCalibrationEnabled(true);

  ceiling_temp.begin();
  floor_temp.begin();

  pinMode(FAN_PWM, OUTPUT);
  pinMode(FAN_ENABLE, OUTPUT);

  //if(CAN0.begin(MCP_ANY, CAN_33K3BPS, MCP_16MHZ) == CAN_OK)
  //  Serial.println("MCP2515 Initialized Successfully!");
  //else
  //  for(;;) Serial.println("Error Initializing MCP2515...");

  //CAN0.setMode(MCP_NORMAL);
}

int pwmv = 0;

void process_data(const char * data){
  String asstr = String(data);
  if (asstr == "set fan on") {
    digitalWrite(FAN_ENABLE, HIGH);
    Serial.println("ack fan on");
  } else if (asstr == "set fan off") {
    digitalWrite(FAN_ENABLE, LOW);
    Serial.println("ack fan off");
  } else if (asstr.startsWith("set fanspeed")) {
    int n  = asstr.substring(String("set fanspeed").length()).toInt();
    analogWrite(FAN_PWM, n);
    Serial.println("ack fanspeed");
  }
}

#define MAX_INPUT 1024

void process_byte (const byte inByte) {
  static char input_line [MAX_INPUT];
  static unsigned int input_pos = 0;

  switch (inByte) {
    case '\n':
      input_line [input_pos] = 0;
      process_data(input_line);
      input_pos = 0;
      break;

    default:
      if (input_pos < (MAX_INPUT - 1))
        input_line [input_pos++] = inByte;
      break;

    case '\r':
      break;
  }
}

unsigned long last_temp_reading = 0;

long unsigned int rxId;
unsigned char len = 0;
unsigned char rxBuf[8];

void loop() {
  //pwmv += 10;
  //if (pwmv >= 255) { 
  //  pwmv = 0;
  //}
  //if (CAN0.readMsgBuf(&rxId, &len, rxBuf) == CAN_OK) {
  //  Serial.println("OWO");
  //}

  if (Serial.available () > 0) process_byte(Serial.read ());

  if (millis() - last_temp_reading > 1000) {
    last_temp_reading = millis();
    float h = ceiling_temp.readHumidity();
    float f = ceiling_temp.readTemperature(true);

    if (!isnan(h) && !isnan(f)) {
      float hif = ceiling_temp.computeHeatIndex(f, h);


      Serial.print("stat ceiling_temp ");
      Serial.print(f);
      Serial.println("");

      Serial.print("stat ceiling_humid ");
      Serial.print(h);
      Serial.println("");

      Serial.print("stat ceiling_heat_index ");
      Serial.print(hif);
      Serial.println("");
    }

    h = floor_temp.readHumidity();
    f = floor_temp.readTemperature(true);

    if (!isnan(h) && !isnan(f)) {
      float hif = floor_temp.computeHeatIndex(f, h);

      Serial.print("stat floor_temp ");
      Serial.print(f);
      Serial.println("");

      Serial.print("stat floor_humid ");
      Serial.print(h);
      Serial.println("");

      Serial.print("stat floor_heat_index ");
      Serial.print(hif);
      Serial.println("");
    }

    if (scd30.dataReady() && scd30.read()){
      Serial.print("stat scd30_temp ");
      Serial.print(ctof(scd30.temperature));
      Serial.println("");

      Serial.print("stat scd30_humid ");
      Serial.print(ctof(scd30.relative_humidity));
      Serial.println("");

      Serial.print("stat scd30_co2 ");
      Serial.print(ctof(scd30.CO2));
      Serial.println("");
    }
  }
}

