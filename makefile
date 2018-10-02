VERSION=0.1
NAME=tennis
LOVEFILE=releases/$(NAME)-$(VERSION).love
LUA := $(wildcard *.lua)
IMAGES := $(wildcard *.png)
AUDIO := $(wildcard *.wav)

run: love .

$(LOVEFILE): $(LUA) $(OUT) $(IMAGES) $(AUDIO)
	mkdir -p releases/
	find $^ -type f | LC_ALL=C sort | env TZ=UTC zip -r -q -9 -X $@ -@

love: $(LOVEFILE)

