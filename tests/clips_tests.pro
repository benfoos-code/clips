QT += core gui testlib
CONFIG += c++17 testcase
TARGET = clips_tests
TEMPLATE = app

INCLUDEPATH += ../src

HEADERS += ../src/backend.h ../src/theme.h ../src/translator.h
SOURCES += clips_tests.cpp ../src/backend.cpp ../src/theme.cpp ../src/translator.cpp
