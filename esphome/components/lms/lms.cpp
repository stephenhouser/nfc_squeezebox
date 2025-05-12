#include "lms.h"
#include "esphome/core/log.h"
#include "esphome/components/network/util.h"

namespace esphome {
namespace lms {

static void url_decode(char *str);

/* Logging tag for component */
static const char *const TAG = "lms";

/* Constructor; initialize async callbacks */
LMSComponent::LMSComponent() {
	// setup handlers for AsyncTCP
	_client.onConnect([](void* obj, AsyncClient* c) { (static_cast<LMSComponent*>(obj))->on_connect(c); }, this);
  	_client.onData([](void* obj, AsyncClient* c, void* data, size_t len) { (static_cast<LMSComponent*>(obj))->on_data(c, static_cast<uint8_t*>(data), len); }, this);
	_client.onError([](void* obj, AsyncClient* c, int8_t error) { (static_cast<LMSComponent*>(obj))->on_error(c, error); }, this);
	_client.onDisconnect([](void* obj, AsyncClient* c) { (static_cast<LMSComponent*>(obj))->on_disconnect(c); }, this);
}

/* *** ESPHome Required Overrides *** */

/* Setup; required override */
void LMSComponent::setup() {
	// Nothing to do here..
	ESP_LOGI(TAG, "LMS Component setup");
}

/* Loop; connect and reconnect when connection lost */
void LMSComponent::loop() {
	// connect when network is up.
	// try reconnecting if we lose our connection.
	// TODO: some sort of pause between reconnection attempts
	if (network::is_connected()) {
		if (this->_connected == false) {
			this->_connected = true;
			ESP_LOGI(TAG, "Connecting to LMS Server %s:%d", _server.c_str(), _port);
			if (!_client.connect(_server.c_str(), _port)) {
				ESP_LOGE(TAG, "connection failed.");
				return;
			}
		}
	}
}

/* Dump Configuration; required override */
void LMSComponent::dump_config() {
  ESP_LOGCONFIG(TAG, "server: %s:%d", _server.c_str(), _port);
  ESP_LOGCONFIG(TAG, "client_id: %s", _client_id);
}


/* *** Tag Actions *** */

/* Send the tag value to the LMS/RFID plugin */
void LMSComponent::send_tag(const std::string &tag_id) {
	if (_connected && !_client_id.empty()) {
		char message[256];
		sprintf(message, "%s rfid tag %s\n", _client_id.c_str(), tag_id.c_str());
		_client.write(message);
	}
}

/* Send that a tag was removed to the LMS. */
void LMSComponent::send_tag_removed() {
	if (_connected && !_client_id.empty()) {
		char message[256];
		sprintf(message, "%s rfid tag removed\n", _client_id.c_str());
		_client.write(message);
	}
}


/* *** Asynchronous TCP Connection Handlers *** */

/* When connection to LMS is complete */
void LMSComponent::on_connect(AsyncClient* client) {
	ESP_LOGI(TAG, "Connected to LMS %s:%d", _server.c_str(), _port);
}

/* When an error occurs on the LMS connection */
void LMSComponent::on_error(AsyncClient* client, int8_t error) {
	ESP_LOGI(TAG, "Error on connection %s:%d", _server.c_str(), _port);
}

/* When data is received from the LMS connection */
void LMSComponent::on_data(AsyncClient* client, uint8_t *data, size_t len) {
	char buffer[256];
	memset(buffer, 0, 256);
	memcpy(buffer, data, len-1);	// don't copy newline
	url_decode(buffer);
	esph_log_i(TAG, "Received data: %s", buffer);
}

/* When the LMS connection is dropped */
void LMSComponent::on_disconnect(AsyncClient* client) {
	ESP_LOGI(TAG, "Disconnected from LMS %s:%d", _server.c_str(), _port);
	this->_connected = false;
}


/* *** Utility Functions *** */

/* Decode URLencoded string, in-place. */
static void url_decode(char *str) {
  char *ptr = str, buf;
  for (; *str; str++, ptr++) {
    if (*str == '%') {
      str++;
      if (parse_hex(str, 2, reinterpret_cast<uint8_t *>(&buf), 1) == 2) {
        *ptr = buf;
        str++;
      } else {
        str--;
        *ptr = *str;
      }
    } else if (*str == '+') {
      *ptr = ' ';
    } else {
      *ptr = *str;
    }
  }
  *ptr = *str;
}

}  // namespace lms
}  // namespace esphome
