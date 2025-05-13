import esphome.config_validation as cv
import esphome.codegen as cg
from esphome.const import CONF_ID
from esphome.core import CORE, coroutine_with_priority

CODEOWNERS = ["@stephenhouser"]

CONF_LMS_PLAYER = 'player'
CONF_LMS_SERVER = 'server'
CONF_LMS_PORT = 'port'

DEPENDENCIES = ["network"]

def AUTO_LOAD():
    if CORE.using_arduino:
        return ["async_tcp"]
    return []

lms_ns = cg.esphome_ns.namespace("lms")
LMSComponent = lms_ns.class_(
    "LMSComponent", cg.Component
)

CONFIG_SCHEMA = cv.Schema({
    cv.GenerateID(): cv.declare_id(LMSComponent),
    cv.Required(CONF_LMS_SERVER): cv.string,
    cv.Required(CONF_LMS_PLAYER): cv.string,
    cv.Optional(CONF_LMS_PORT, default=9090): cv.int_range(min=1, max=65535),
}).extend(cv.COMPONENT_SCHEMA)


async def to_code(config):
    var = cg.new_Pvariable(config[CONF_ID])
    await cg.register_component(var, config)

    cg.add(var.set_player(config[CONF_LMS_PLAYER]))
    cg.add(var.set_server(config[CONF_LMS_SERVER]))
    if CONF_LMS_PORT in config:
        cg.add(var.set_port(config[CONF_LMS_PORT]))

    if CORE.using_arduino:
        if CORE.is_esp32:
            cg.add_library("WiFi", None)
