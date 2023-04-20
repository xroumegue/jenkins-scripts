whatis("Version: SC_VERSION ")

setenv("SYSTEMC_HOME", "SC_PREFIX/SC_VERSION")
setenv("SYSTEMC", "SC_PREFIX/SC_VERSION")
setenv("SYSTEMC_INCLUDE", "SC_PREFIX/SC_VERSION/include")
setenv("SYSTEMC_LIBDIR", "SC_PREFIX/SC_VERSION/lib-linux64")
prepend_path( "LD_LIBRARY_PATH", "SC_PREFIX/SC_VERSION/lib-linux64")
prepend_path( "PKG_CONFIG_PATH", "SC_PREFIX/SC_VERSION/lib-linux64/pkgconfig")
