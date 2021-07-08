;;; This file is part of cl-gmsk-transfer
;;; Copyright 2021 Guillaume LE VAILLANT
;;; Distributed under the GNU GPL v3 or later.
;;; See the file LICENSE for terms of use and distribution.

(defsystem "gmsk-transfer"
  :name "gmsk-transfer"
  :description "Send and receive data with SDRs using GMSK modulation"
  :version "1.0"
  :author "Guillaume LE VAILLANT"
  :license "GPL-3"
  :depends-on ("cffi")
  :components ((:file "gmsk-transfer")))
