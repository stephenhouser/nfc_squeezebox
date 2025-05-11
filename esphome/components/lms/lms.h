#pragma once

// #include "esphome.h"
#include "esphome/core/component.h"
#include "esphome/core/hal.h"
#include "esphome/core/helpers.h"
#include <cstdlib>
#include <utility>

#include <AsyncTCP.h>

namespace esphome {
namespace lms {

class LMSComponent : public Component {
	public:
		LMSComponent();

		void setup() override;
		void loop() override;
		void dump_config() override;

		void set_server(std::string server) { _server = std::move(server); }
		std::string get_server() { return _server; }

		void set_port(int port) { _port = port; }
		int get_port() { return _port; }

		void send_tag(const char *tag_id);

	private:
		AsyncClient _client;
		std::string _server = "10.1.10.2";
		uint16_t _port = 9090;

		std::string _player_id;

		bool _connected = false;

		void on_connect(AsyncClient* client);
		void on_data(AsyncClient* client, uint8_t* data, size_t len);
		void on_error(AsyncClient* client, int8_t error);
		void on_disconnect(AsyncClient* client);

		void request_paired_client();
};

}	// namespace lms
}	// namespace esphome
