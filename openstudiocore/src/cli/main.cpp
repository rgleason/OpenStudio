#include <QByteArray>
#include <QtPlugin>

#include "RubyInterpreter.hpp"
#include "GC_Value.hpp"
#include "InitMacros.hxx"
#include "../../ruby/init_openstudio.hpp"
#include <embedded_files.hxx>

#include <iostream>

#ifndef _MSC_VER
#include <dlfcn.h>
#include <dirent.h>
#else
#include <windows.h>
#endif


extern "C" {
  void Init_EmbeddedScripting(void);
  INIT_DECLARATIONS;

  void Init_generator(void);
  void Init_parser(void);
  void Init_Encoding(void);
  void Init_md5(void);
  void Init_rmd160(void);
  void Init_sha1(void);
  void Init_sha2(void);

  void Init_encdb();
  void Init_big5();
  void Init_cp949();
  void Init_emacs_mule();
  void Init_euc_jp();
  void Init_euc_kr();
  void Init_euc_tw();
  void Init_gb2312();
  void Init_gb18030();
  void Init_gbk();
  void Init_iso_8859_1();
  void Init_iso_8859_2();
  void Init_iso_8859_3();
  void Init_iso_8859_4();
  void Init_iso_8859_5();
  void Init_iso_8859_6();
  void Init_iso_8859_7();
  void Init_iso_8859_8();
  void Init_iso_8859_9();
  void Init_iso_8859_10();
  void Init_iso_8859_11();
  void Init_iso_8859_13();
  void Init_iso_8859_14();
  void Init_iso_8859_15();
  void Init_iso_8859_16();
  void Init_koi8_r();
  void Init_koi8_u();
  void Init_shift_jis();
  void Init_utf_16be();
  void Init_utf_16le();
  void Init_utf_32be();
  void Init_utf_32le();
  void Init_windows_31j();
  void Init_windows_1251();

  void Init_transdb();
  void Init_trans_big5();
  void Init_trans_chinese();
  void Init_trans_emoji();
  void Init_trans_emoji_iso2022_kddi();
  void Init_trans_emoji_sjis_docomo();
  void Init_trans_emoji_sjis_kddi();
  void Init_trans_emoji_sjis_softbank();
  void Init_trans_escape();
  void Init_trans_gb18030();
  void Init_trans_gbk();
  void Init_trans_iso2022();
  void Init_trans_japanese();
  void Init_trans_japanese_euc();
  void Init_trans_japanese_sjis();
  void Init_trans_korean();
  void Init_trans_single_byte();
  void Init_trans_utf8_mac();
  void Init_trans_utf_16_32();
}

std::vector<std::string> paths;
static RubyInterpreter rubyInterpreter(paths);//(paths);

int main(int argc, char *argv[])
{
  ruby_sysinit(&argc, &argv);
  {
    RUBY_INIT_STACK;
    ruby_init();

    swig::GC_VALUE::hash_id = rb_intern("hash");
    swig::GC_VALUE::lt_id = rb_intern("<");
    swig::GC_VALUE::gt_id = rb_intern(">");
    swig::GC_VALUE::eq_id = rb_intern("==");
    swig::GC_VALUE::le_id = rb_intern("<=");
    swig::GC_VALUE::ge_id = rb_intern(">=");

    swig::GC_VALUE::pos_id = rb_intern("+@");
    swig::GC_VALUE::neg_id = rb_intern("-@");
    swig::GC_VALUE::inv_id = rb_intern("~");

    swig::GC_VALUE::add_id = rb_intern("+");
    swig::GC_VALUE::sub_id = rb_intern("-");
    swig::GC_VALUE::mul_id = rb_intern("*");
    swig::GC_VALUE::div_id = rb_intern("/");
    swig::GC_VALUE::mod_id = rb_intern("%");

    swig::GC_VALUE::and_id = rb_intern("&");
    swig::GC_VALUE::or_id  = rb_intern("|");
    swig::GC_VALUE::xor_id = rb_intern("^");

    swig::GC_VALUE::lshift_id = rb_intern("<<");
    swig::GC_VALUE::rshift_id = rb_intern(">>");

    INIT_CALLS;

    Init_encdb();
    rb_provide("enc/encdb.so");
    Init_big5();
    rb_provide("enc/big5.so");
    Init_cp949();
    rb_provide("enc/cp949.so");
    Init_emacs_mule();
    rb_provide("enc/emacs_mule.so");
    Init_euc_jp();
    rb_provide("enc/euc_jp.so");
    Init_euc_kr();
    rb_provide("enc/euc_kr.so");
    Init_euc_tw();
    rb_provide("enc/euc_tw.so");
    Init_gb2312();
    rb_provide("enc/gb2312.so");
    Init_gb18030();
    rb_provide("enc/gb18030.so");
    Init_gbk();
    rb_provide("enc/gbk.so");
    Init_iso_8859_1();
    rb_provide("enc/iso_8859_1.so");
	  Init_iso_8859_2();
    rb_provide("enc/iso_8859_2.so");
    Init_iso_8859_3();
    rb_provide("enc/iso_8859_3.so");
	  Init_iso_8859_4();
    rb_provide("enc/iso_8859_4.so");
    Init_iso_8859_5();
    rb_provide("enc/iso_8859_5.so");
    Init_iso_8859_6();
    rb_provide("enc/iso_8859_6.so");
    Init_iso_8859_7();
    rb_provide("enc/iso_8859_7.so");
    Init_iso_8859_8();
    rb_provide("enc/iso_8859_8.so");
    Init_iso_8859_9();
    rb_provide("enc/iso_8859_9.so");
    Init_iso_8859_10();
    rb_provide("enc/iso_8859_10.so");
    Init_iso_8859_11();
    rb_provide("enc/iso_8859_11.so");
    Init_iso_8859_13();
    rb_provide("enc/iso_8859_13.so");
    Init_iso_8859_14();
    rb_provide("enc/iso_8859_14.so");
    Init_iso_8859_15();
    rb_provide("enc/iso_8859_15.so");
    Init_iso_8859_16();
    rb_provide("enc/iso_8859_16.so");
    Init_koi8_r();
    rb_provide("enc/koi8_r.so");
    Init_koi8_u();
    rb_provide("enc/koi8_u.so");
    Init_shift_jis();
    rb_provide("enc/shift_jis.so");
    Init_utf_16be();
    rb_provide("enc/utf_16be.so");
    Init_utf_16le();
    rb_provide("enc/utf_16le.so");
    Init_utf_32be();
    rb_provide("enc/utf_32be.so");
    Init_utf_32le();
    rb_provide("enc/utf_32le.so");
    Init_windows_31j();
    rb_provide("enc/windows_31j.so");
    Init_windows_1251();
    rb_provide("enc/windows_1251.so");

    Init_transdb();
    rb_provide("enc/trans/transdb.so");
    Init_trans_big5();
    rb_provide("enc/trans/big5.so");
    Init_trans_chinese();
    rb_provide("enc/trans/chinese.so");
    Init_trans_emoji();
    rb_provide("enc/trans/emoji.so");
    Init_trans_emoji_iso2022_kddi();
    rb_provide("enc/trans/emoji_iso2022_kddi.so");
    Init_trans_emoji_sjis_docomo();
    rb_provide("enc/trans/emoji_sjis_docomo.so");
    Init_trans_emoji_sjis_kddi();
    rb_provide("enc/trans/emoji_sjis_kddi.so");
    Init_trans_emoji_sjis_softbank();
    rb_provide("enc/trans/emoji_sjis_softbank.so");
    Init_trans_escape();
    rb_provide("enc/trans/escape.so");
    Init_trans_gb18030();
    rb_provide("enc/trans/gb18030.so");
    Init_trans_gbk();
    rb_provide("enc/trans/gbk.so");
    Init_trans_iso2022();
    rb_provide("enc/trans/iso2022.so");
    Init_trans_japanese();
    rb_provide("enc/trans/japanese.so");
    Init_trans_japanese_euc();
    rb_provide("enc/trans/japanese_euc.so");
    Init_trans_japanese_sjis();
    rb_provide("enc/trans/japanese_sjis.so");
    Init_trans_korean();
    rb_provide("enc/trans/korean.so");
    Init_trans_single_byte();
    rb_provide("enc/trans/single_byte.so");
    Init_trans_utf8_mac();
    rb_provide("enc/trans/utf8_mac.so");
    Init_trans_utf_16_32();
    rb_provide("enc/trans/utf_16_32.so");

    init_openstudio_internal();

    Init_md5();
    rb_provide("digest/md5");
    Init_rmd160();
    rb_provide("digest/rmd160");
    Init_sha1();
    rb_provide("digest/sha1");
    Init_sha2();
    rb_provide("digest/sha2");

    Init_EmbeddedScripting();
  }
  
  #ifdef QT_STATIC
  Q_IMPORT_PLUGIN(QSQLiteDriverPlugin);
  #endif

  // Need embedded_help for requiring files out of the embedded system
  auto embedded_extensions_string = embedded_files::getFileAsString(":/embedded_help.rb");
  rubyInterpreter.evalString(embedded_extensions_string);

  // chop off the first argument which is the exe path/name
  ruby_set_argv(argc - 1,argv + 1);

  try{
    rubyInterpreter.evalString("begin \n (require 'openstudio_cli') \n rescue Exception => e \n puts \n puts \"Error: #{e.message}\" \n puts \"Backtrace:\n\t\" + e.backtrace.join(\"\\n\\t\") \n raise \n end");
  } catch (const std::exception& e){
    rubyInterpreter.evalString(R"(STDOUT.flush)");
    std::cout << "Exception: " << e.what() << std::endl; // endl will flush
    return 1;
  } catch (...){
    rubyInterpreter.evalString(R"(STDOUT.flush)");
    std::cout << "Unknown Exception" << std::endl; // endl will flush
    return 1;
  }
  rubyInterpreter.evalString(R"(STDOUT.flush)");
  std::cout << std::flush;
  return 0;
}

extern "C" {
  int rb_hasFile(const char *t_filename) {
    // TODO Consider expanding this to use the path which we have artificially defined in embedded_help.rb
    std::string expandedName = std::string(":/ruby/2.0.0/") + std::string(t_filename) + ".rb";
    return embedded_files::hasFile(expandedName);
  }

  int rb_require_embedded(const char *t_filename) {
    std::string require_script = R"(require ')" + std::string(t_filename) + R"(')";
    rubyInterpreter.evalString(require_script);
    return 0;
  }
}
