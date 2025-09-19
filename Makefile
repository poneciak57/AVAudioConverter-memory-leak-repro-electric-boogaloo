
# compiling Objective-C++ files

./bin/%: %.mm | prep
	clang++ -std=c++17 -framework Foundation -framework AVFoundation -o $@ $<

prep: 
	mkdir -p ./bin

%: ./bin/%
	$<

