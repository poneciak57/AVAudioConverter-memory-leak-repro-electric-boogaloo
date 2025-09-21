
# This requires ARC
./bin/repro1: repro1.mm | prep
	clang++ -std=c++17 -fobjc-arc -framework Foundation -framework AVFoundation -o $@ $<

./bin/%: %.mm | prep
	clang++ -std=c++17 -framework Foundation -framework AVFoundation -o $@ $<

prep: 
	mkdir -p ./bin

%: ./bin/%
	$<

