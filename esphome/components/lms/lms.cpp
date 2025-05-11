#include <vector>

#include "lms.h"
#include "esphome/core/log.h"
#include "esphome/components/network/util.h"

namespace esphome {
namespace lms {

static void url_decode(char *str);
static const std::vector<std::string> split_str(const std::string &str, const std::string &delim = ", =;");
static bool is_command(std::vector<std::string> key, std::vector<std::string> needle);


static const char *const TAG = "lms";

// /* event callbacks, patch to component passes as arg */
// static void handleData(void* arg, AsyncClient* client, void *data, size_t len) {
// 	// ESP_LOGI(TAG, "handleData(): %d", len);
// 	LMSComponent *lms = static_cast<LMSComponent *>(arg);
// 	lms->on_data(data, len);
// }

// static void onConnect(void* arg, AsyncClient* client) {
// 	// ESP_LOGI(TAG, "onConnect()");
// 	LMSComponent *lms = static_cast<LMSComponent *>(arg);
// 	lms->on_connect();
// }

LMSComponent::LMSComponent() {
	_client.onConnect([](void* obj, AsyncClient* c) { (static_cast<LMSComponent*>(obj))->on_connect(c); }, this);
  	_client.onData([](void* obj, AsyncClient* c, void* data, size_t len) { (static_cast<LMSComponent*>(obj))->on_data(c, static_cast<uint8_t*>(data), len); }, this);
	_client.onError([](void* obj, AsyncClient* c, int8_t error) { (static_cast<LMSComponent*>(obj))->on_error(c, error); }, this);
	_client.onDisconnect([](void* obj, AsyncClient* c) { (static_cast<LMSComponent*>(obj))->on_disconnect(c); }, this);
}

void LMSComponent::setup() {
	ESP_LOGI(TAG, "LMS Component setup");
}

void LMSComponent::loop() {
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

void LMSComponent::dump_config() {
  ESP_LOGCONFIG(TAG, "Server: %s:%d", _server, _port);
}

void LMSComponent::send_tag(const char *tag_id) {
	if (!_player_id.empty()) {
		char message[256];
		sprintf(message, "rfid tag %s\n", tag_id);
		_client.write(message);
	}
}

void LMSComponent::on_connect(AsyncClient* client) {
	esph_log_i(TAG, "lms::on_connect(): %s:%d", _server.c_str(), _port);
	this->request_paired_client();
}

void LMSComponent::on_error(AsyncClient* client, int8_t error) {
	esph_log_e(TAG, "lms::on_error(): %s:%d", _server.c_str(), _port);
}

void LMSComponent::on_data(AsyncClient* client, uint8_t *data, size_t len) {
	char buffer[256];
	memset(buffer, 0, 256);
	memcpy(buffer, data, len-1);	// skip newline
	url_decode(buffer);
	esph_log_i(TAG, "lms::on_data(%s)", buffer);

	std::vector<std::string> cmd = split_str(buffer, " ");
	if (is_command({"rfid", "pair"}, cmd) && cmd.size() == 4) {
		_player_id = cmd[3];
		esph_log_i(TAG, "lms::paired with playerId %s", _player_id.c_str());
	}

}

void LMSComponent::on_disconnect(AsyncClient* client) {
	esph_log_i(TAG, "lms::on_disconnect(): %s:%d", _server.c_str(), _port);
	this->_connected = false;
}

void LMSComponent::request_paired_client() {
	char message[256];
	sprintf(message, "rfid pair %s ?\n", get_mac_address_pretty().c_str());
	//esph_log_i(TAG, "send: %s", message);
	_client.write(message);
}


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

static const std::vector<std::string> split_str(const std::string &str, const std::string &delim) {
    std::vector<std::string> tokens;
    char *str_c { strdup(str.c_str()) };
    char *token { NULL };

    token = strtok(str_c, delim.c_str()); 
    while (token != NULL) { 
        tokens.push_back(std::string(token));  
        token = strtok(NULL, delim.c_str()); 
    }

    free(str_c);
    return tokens;
}

static bool is_command(std::vector<std::string> key, std::vector<std::string> needle) {
	if (needle.size() < key.size()) {
		return false;
	}

	for (int i = 0; i < key.size(); i++) {
		if (key[i] != needle[i]) {
			return false;
		}
	}

	return true;
}

}  // namespace lms
}  // namespace esphome
