#makefile for c++ programs
#change the name of the executable to use for "any" project

EXECUTABLE =./test

LINKCC = $(CXX)

#CXXFLAGS denotes flags for the C++ compiler

CXX = g++

#uncomment this line if you are using gcc 4.x
#CXXFLAGS = -DBOOST_LOG_DYN_LINK -std=c++11 -DGCC4_3 -DPLUGGABLE_SCORING
CXXFLAGS =

#LDFLAGS = -lboost_thread -lboost_log -lboost_system -lpthread -L/usr/lib -lm -lexpat
LDFLAGS = -lrt

SRCS := $(wildcard *.cpp)
OBJS := $(patsubst %.cpp,%.o,$(wildcard *.cpp))
DEPS := $(patsubst %.o,%.d,$(OBJS))
jall: $(EXECUTABLE)

#define the components of the program, and how to link them
#these components are defined as dependencies; that is they must be up-to-date before the code is linked

$(EXECUTABLE): $(DEPS) $(OBJS)
	$(LINKCC) $(CXXFLAGS) -o $(EXECUTABLE) $(OBJS) $(LDFLAGS)

#specify the dep files depend on the cpp files

%.d: %.cpp
	$(CXX) -M $(CXXFLAGS) $< > $@
	$(CXX) -M $(CXXFLAGS) $< | sed s/\\.o/.d/ > $@

clean:
	-rm $(OBJS) $(EXECUTABLE) $(DEPS) 

explain:
	@echo "The following info represents the program:"
	@echo "Final exec name: $(EXECUTABLE)"
	@echo "Source files:       $(SRCS)"
	@echo "Object files:       $(OBJS)"
	@echo "Dep files:          $(DEPS)"

depend: $(DEPS)
	@echo "Deps are now up-to-date."
 	
-include $(DEPS)
