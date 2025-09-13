// Relay pins (using GPIO numbers)
int relay1 = D1; // GPIO5
int relay2 = D2; // GPIO4

void setup()
{
    pinMode(relay1, OUTPUT);
    pinMode(relay2, OUTPUT);

    // Make sure relays are OFF at start
    digitalWrite(relay1, HIGH); // for active LOW relays
    digitalWrite(relay2, HIGH);
}

void loop()
{
    // Relay 1 ON
    digitalWrite(relay1, LOW);
    delay(2000);

    // Relay 2 ON
    digitalWrite(relay2, LOW);
    delay(2000);

    // Relay 1 OFF
    digitalWrite(relay1, HIGH);
    delay(2000);

    // Relay 2 OFF
    digitalWrite(relay2, HIGH);
    delay(2000);
}
