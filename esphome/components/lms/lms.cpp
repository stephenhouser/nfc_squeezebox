#include <vector>
#include <queue>

#include "lms.h"
#include "esphome/core/log.h"
#include "esphome/components/network/util.h"

namespace esphome {
namespace lms {

static char *url_decode(uint8_t *str);
static const std::vector<std::string> split_str(const std::string &str, const std::string &delim = ", =;");
static const char *token(const char *str, int token_number);

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

	if (_client.canSend() && !this->_queue.empty()) {
		auto cmd = _queue.front();
		_queue.pop();

		ESP_LOGD(TAG, "Send: [%s]", cmd.c_str());
		_client.write(cmd.c_str());
		_client.write("\n");
	}
}

/* Dump Configuration; required override */
void LMSComponent::dump_config() {
  ESP_LOGCONFIG(TAG, "server: %s:%d", _server.c_str(), _port);
  ESP_LOGCONFIG(TAG, "player: %s", _player.c_str());
}


/* *** Tag Actions *** */

/* Send the tag value to the LMS/RFID plugin */
void LMSComponent::send_tag(const std::string &tag_id) {
	if (_connected && !_player_id.empty()) {
		char message[256];
		sprintf(message, "%s rfid tag %s", _player_id.c_str(), tag_id.c_str());
		_queue.push(message);
	}
}

/* Send that a tag was removed to the LMS. */
void LMSComponent::send_tag_removed() {
	if (_connected && !_player_id.empty()) {
		char message[256];
		sprintf(message, "%s rfid tag removed", _player_id.c_str());
		_queue.push(message);
	}
}


/* *** Asynchronous TCP Connection Handlers *** */

/* When connection to LMS is complete */
void LMSComponent::on_connect(AsyncClient* client) {
	ESP_LOGI(TAG, "Connected to LMS %s:%d", _server.c_str(), _port);
	request_player_id();
}

/* When an error occurs on the LMS connection */
void LMSComponent::on_error(AsyncClient* client, int8_t error) {
	ESP_LOGI(TAG, "Error on connection %s:%d", _server.c_str(), _port);
}

/* When data is received from the LMS connection */
void LMSComponent::on_data(AsyncClient* client, uint8_t *data, size_t len) {
	data[len-1] = 0;	// last newline
	char *cdata = strtok(url_decode(data), "\n");
	while (cdata) {

		ESP_LOGD(TAG, "Receive: [%s]", cdata);

		if (!strncmp("player count", cdata, 12)) {
			/* tells us how many players there are */
			int count = atoi(token(cdata, 2));
			ESP_LOGD(TAG, "player count [%d]", count);

			/* queue up queries for each player's name */
			for (int i = 0; i < count; i++) {
				char buffer[32];
				sprintf(buffer, "player name %d ?", i);
				_queue.push(buffer);
			}
		} else if (!strncmp("player name ", cdata, 12)) {
			/* check if this player name matches what we are looking for */
			int player_idx = atoi(token(cdata, 2));
			const char *player_name = token(cdata, 3);
			if (!strcmp(_player.c_str(), player_name)) {
				/* This is the player we are looking for, 
				send out a query for it's client id */
				ESP_LOGD(TAG, "Found player %d is [%s]", player_idx, player_name);

				char buffer[32];
				sprintf(buffer, "player id %d ?", player_idx);
				_queue.push(buffer);
			}

		} else if (!strncmp("player id ", cdata, 10)) {
			/* this should be the id of the player we are looking for */
			_player_id = token(cdata, 3);
			ESP_LOGI(TAG, "Player [%s] has client_id [%s]", _player.c_str(), _player_id.c_str());
		}

		cdata = strtok(NULL, "\n");
	}
}

/* When the LMS connection is dropped */
void LMSComponent::on_disconnect(AsyncClient* client) {
	ESP_LOGI(TAG, "Disconnected from LMS %s:%d", _server.c_str(), _port);
	_connected = false;
	invalidate_player_id();
}

void LMSComponent::request_player_id() {
	/* queue up a request that starts our player id discovery process */
	_queue.push("player count ?");
}

void LMSComponent::invalidate_player_id() {
	/* Reset to unknown player id */
	_player_id.clear();
}

/* *** Utility Functions *** */

/* Decode URLencoded string, in-place. */
static char *url_decode(uint8_t *u_str) {
	char *str = (char *)u_str;
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

  	return (char *)u_str;
}

const std::vector<std::string> split_str(const std::string &str, const std::string &delim) {
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

const char *token(const char *str, int token_number) {
	while (*str && token_number--) {
		while (*str && *str != ' ') {	// find whitespace
			str++;
		}
		
		while (*str && *str == ' ') {	// find non-whitespace
			str++;
		}
	}

	return str;
}

}  // namespace lms
}  // namespace esphome
