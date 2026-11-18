# frozen_string_literal: true

class Ogrenci
  DURUMLAR = %i[aktif donduruldu mezun].freeze
  OTURUM_SAYISI = 10

  attr_reader :ad, :durum, :devamsizlik

  def initialize(ad:, durum:, devamsizlik:)
    unless DURUMLAR.include?(durum)
      raise ArgumentError, "durum #{DURUMLAR.inspect} içinden olmalı: #{durum.inspect}"
    end
    unless devamsizlik.is_a?(Integer) && devamsizlik.between?(0, OTURUM_SAYISI)
      raise ArgumentError, "devamsizlik 0..#{OTURUM_SAYISI} arası Integer olmalı: #{devamsizlik.inspect}"
    end

    @ad = ad
    @durum = durum
    @devamsizlik = devamsizlik
  end

  DURUMLAR.each do |d|
    define_method(:"#{d}?") { @durum == d }
  end
end
