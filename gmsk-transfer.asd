;;; This file is part of cl-gmsk-transfer
;;; Copyright 2021-2022 Guillaume LE VAILLANT
;;; Distributed under the GNU GPL v3 or later.
;;; See the file LICENSE for terms of use and distribution.

(defsystem "gmsk-transfer"
  :name "gmsk-transfer"
  :description "Send and receive data with SDRs using GMSK modulation"
  :version "1.6"
  :author "Guillaume LE VAILLANT"
  :license "GPL-3"
  :depends-on ("cffi" "cl-octet-streams" "float-features")
  :in-order-to ((test-op (test-op "gmsk-transfer/tests")))
  :components ((:file "gmsk-transfer")))

(defsystem "gmsk-transfer/tests"
  :name "gmsk-transfer/tests"
  :description "Tests fot gmsk-transfer"
  :version "1.6"
  :author "Guillaume LE VAILLANT"
  :license "GPL-3"
  :depends-on ("fiveam" "gmsk-transfer" "uiop")
  :in-order-to ((test-op (load-op "gmsk-transfer/tests")))
  :perform (test-op (o s)
             (let ((tests (uiop:find-symbol* 'gmsk-transfer-tests
                                             :gmsk-transfer-tests)))
               (uiop:symbol-call :fiveam 'run! tests)))
  :components ((:file "tests")))
