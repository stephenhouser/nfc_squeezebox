# Compile and Deploy ESPHome-based RFID/LMS Connection
# Includes `LMSComponent` an external component for ESPHome, `lms`

# Requires Docker to run the `esphome` script contained here

fake:
	@echo "Targets:"
	@echo " - reader    compile and deploy ESPHome reader (on /dev/ttyUSB0)"
	@echo " - compile   compile ESPHome example, check code"
	@echo " - clean     clean up ESPHome stuff"
	@echo " - distclean really clean up ESPHome stuff"

reader:
	./esphome run rfid_squeezer.yaml

compile:
	./esphome compile rfid_squeezer.yaml

clean:
	./esphome clean rfid_squeezer.yaml

distclean:
	rm -rf .esphome
	rm -rf components/lms/__pycache__
