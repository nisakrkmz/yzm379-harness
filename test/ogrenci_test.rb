# frozen_string_literal: true

# Sensör katmanı: şartnamedeki sınır vakalarını ve yasakları kilitler.
# Çalıştırma: ruby -Ilib -Itest test/ogrenci_test.rb

require "minitest/autorun"
require_relative "../lib/ogrenci"
require_relative "../lib/devamsizlik_kontrol"

LIB_DIZINI = File.expand_path("../lib", __dir__)

def ogrenci(devamsizlik: 0, durum: :aktif, ad: "Ayşe")
  Ogrenci.new(ad: ad, durum: durum, devamsizlik: devamsizlik)
end

def kontrol(devamsizlik: 0, durum: :aktif)
  DevamsizlikKontrol.new(ogrenci(devamsizlik: devamsizlik, durum: durum))
end

class OgrenciTest < Minitest::Test
  def test_alanlar_okunabilir
    o = ogrenci(devamsizlik: 2, durum: :donduruldu, ad: "Ali")
    assert_equal "Ali", o.ad
    assert_equal :donduruldu, o.durum
    assert_equal 2, o.devamsizlik
  end

  def test_durum_sorgulari_dogru_cevap_verir
    assert ogrenci(durum: :aktif).aktif?
    refute ogrenci(durum: :aktif).mezun?
    assert ogrenci(durum: :mezun).mezun?
    assert ogrenci(durum: :donduruldu).donduruldu?
    refute ogrenci(durum: :donduruldu).aktif?
  end

  # define_method şartı: metotlar gerçekten tanımlı ve aranabilir olmalı.
  def test_durum_sorgulari_acik_ve_aranabilir
    %i[aktif? donduruldu? mezun?].each do |m|
      assert_includes Ogrenci.public_instance_methods(false), m
      assert ogrenci.respond_to?(m), "#{m} respond_to? ile bulunamadı"
    end
  end

  def test_bilinmeyen_metot_no_method_error_firlatir
    o = ogrenci
    refute o.respond_to?(:ucuyor?)
    assert_raises(NoMethodError) { o.ucuyor? }
    assert_raises(NoMethodError) { o.aktif_mi? }
  end

  def test_method_missing_tanimlanmamis
    assert_equal BasicObject, Ogrenci.instance_method(:method_missing).owner
    assert_equal BasicObject, DevamsizlikKontrol.instance_method(:method_missing).owner
    refute Ogrenci.private_instance_methods(false).include?(:respond_to_missing?)
  end

  # Açık sınıf yasağı: lib/ içindeki kod standart sınıflara metot eklememeli.
  def test_standart_siniflara_monkey_patch_yok
    [Object, Kernel, BasicObject, Integer, Numeric, Float, String, Symbol,
     Array, Hash, NilClass, TrueClass, FalseClass, Comparable, Range].each do |k|
      (k.instance_methods(false) + k.private_instance_methods(false)).each do |m|
        yer = k.instance_method(m).source_location&.first
        refute yer&.start_with?(LIB_DIZINI), "#{k}##{m} lib/ içinde tanımlanmış (monkey patch)"
      end
    end
  end

  def test_gecersiz_durum_reddedilir
    assert_raises(ArgumentError) { ogrenci(durum: :silindi) }
    assert_raises(ArgumentError) { ogrenci(durum: "aktif") }
  end

  # A koşusu 2. tur: ajan durum için kendiliğinden :aktif varsayılanı koydu.
  def test_alanlar_zorunlu_varsayilan_yok
    assert_raises(ArgumentError) { Ogrenci.new(ad: "Ali", devamsizlik: 0) }
    assert_raises(ArgumentError) { Ogrenci.new(ad: "Ali", durum: :aktif) }
    assert_raises(ArgumentError) { Ogrenci.new(durum: :aktif, devamsizlik: 0) }
  end

  def test_devamsizlik_sinirlari_0_ve_10_kabul_edilir
    assert_equal 0, ogrenci(devamsizlik: 0).devamsizlik
    assert_equal 10, ogrenci(devamsizlik: 10).devamsizlik
  end

  def test_devamsizlik_araligi_disi_reddedilir
    assert_raises(ArgumentError) { ogrenci(devamsizlik: -1) }
    assert_raises(ArgumentError) { ogrenci(devamsizlik: 11) }
    assert_raises(ArgumentError) { ogrenci(devamsizlik: 2.5) }
    assert_raises(ArgumentError) { ogrenci(devamsizlik: "3") }
    assert_raises(ArgumentError) { ogrenci(devamsizlik: nil) }
  end
end

class DevamsizlikKontrolTest < Minitest::Test
  # --- Kural 1: riskli (>= 3) ---
  def test_2_devamsizlik_riskli_degil
    refute kontrol(devamsizlik: 2).riskli?
  end

  def test_tam_3_devamsizlik_riskli_sayilir # SINIR VAKA: %30 dahil
    assert kontrol(devamsizlik: 3).riskli?
  end

  def test_3_ustu_riskli
    (3..10).each { |d| assert kontrol(devamsizlik: d).riskli?, "#{d} riskli olmalı" }
    (0..2).each { |d| refute kontrol(devamsizlik: d).riskli?, "#{d} riskli olmamalı" }
  end

  # --- Kural 2: kaldi (>= 4) ---
  def test_tam_3_devamsizlik_kalmaz
    refute kontrol(devamsizlik: 3).kaldi?
  end

  def test_tam_4_devamsizlik_kaldi
    assert kontrol(devamsizlik: 4).kaldi?
  end

  def test_4_devamsizlik_hem_riskli_hem_kaldi
    k = kontrol(devamsizlik: 4)
    assert k.riskli?
    assert k.kaldi?
  end

  # --- Kural 3 (özgün): onur_adayi = aktif ve 0 devamsızlık ---
  def test_aktif_ve_sifir_devamsizlik_onur_adayi
    assert kontrol(devamsizlik: 0, durum: :aktif).onur_adayi?
  end

  def test_tek_devamsizlik_onur_adayligini_bozar
    refute kontrol(devamsizlik: 1, durum: :aktif).onur_adayi?
  end

  def test_aktif_olmayan_onur_adayi_olamaz
    refute kontrol(devamsizlik: 0, durum: :mezun).onur_adayi?
    refute kontrol(devamsizlik: 0, durum: :donduruldu).onur_adayi?
  end

  # --- Toplu sonuç ---
  def test_kurallar_listesi
    assert_equal [], kontrol(devamsizlik: 2).kurallar
    assert_equal [:riskli], kontrol(devamsizlik: 3).kurallar
    assert_equal %i[riskli kaldi], kontrol(devamsizlik: 4).kurallar
    assert_equal [:onur_adayi], kontrol(devamsizlik: 0).kurallar
    assert_equal [], kontrol(devamsizlik: 0, durum: :mezun).kurallar
  end
end
