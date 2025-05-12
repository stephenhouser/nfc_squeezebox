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

		/* *** ESPHome Required Overrides *** */
		void setup() override;
		void loop() override;
		void dump_config() override;

		/* *** Setters and Getters for Parameters *** */
		void set_client_id(std::string client_id) { _client_id = std::move(client_id); }
		std::string get_client_id() { return _client_id; }

		void set_server(std::string server) { _server = std::move(server); }
		std::string get_server() { return _server; }

		void set_port(int port) { _port = port; }
		int get_port() { return _port; }

		/* *** Tag Actions *** */
		void send_tag(const std::string &tag);
		void send_tag_removed();

	private:
		AsyncClient _client;	/* TCP connection client */		
		std::string _client_id;	/* LMS client id; in hex (b8:27:eb:4f:71:11) */
		std::string _server;	/* LMS server address */
		uint16_t _port = 9090;	/* LMS server port */

		bool _connected = false;	/* are we connected? */

		/* *** Asynchronous TCP Connection Handlers *** */
		void on_connect(AsyncClient* client);
		void on_data(AsyncClient* client, uint8_t* data, size_t len);
		void on_error(AsyncClient* client, int8_t error);
		void on_disconnect(AsyncClient* client);
};

}	// namespace lms
}	// namespace esphome
