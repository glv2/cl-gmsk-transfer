;;; This file is part of cl-gmsk-transfer
;;; Copyright 2021 Guillaume LE VAILLANT
;;; Distributed under the GNU GPL v3 or later.
;;; See the file LICENSE for terms of use and distribution.

(defpackage :gmsk-transfer
  (:use :cl)
  (:import-from :cffi
                #:callback
                #:defcallback
                #:defcfun
                #:define-foreign-library
                #:mem-aref
                #:null-pointer
                #:null-pointer-p
                #:use-foreign-library)
  (:export #:free-transfer
           #:make-transfer
           #:start-transfer
           #:stop-all-transfers
           #:stop-transfer
           #:transmit-file
           #:transmit-stream
           #:receive-file
           #:receive-stream
           #:verbosity))

(in-package :gmsk-transfer)


;;;
;;; Bindings to libgmsk-transfer
;;;

(define-foreign-library gmsk-transfer
  (:unix (:or "libgmsk-transfer.so"
              "libgmsk-transfer.so.1"))
  (t (:default "libgmsk-transfer")))

(use-foreign-library gmsk-transfer)

(defcfun ("gmsk_transfer_set_verbose" gmsk-transfer-set-verbose) :void
  "Set the verbosity level."
  (v :unsigned-char))

(defcfun ("gmsk_transfer_is_verbose" gmsk-transfer-is-verbose) :unsigned-char
  "Get the verbosity level.")

(defcfun ("gmsk_transfer_create" gmsk-transfer-create) :pointer
  "Initialize a new transfer."
  (radio-driver :string)
  (emit :unsigned-char)
  (file :string)
  (sample-rate :unsigned-long)
  (bit-rate :unsigned-int)
  (frequency :unsigned-long)
  (frequency-offset :long)
  (gain :unsigned-int)
  (ppm :float)
  (inner-fec :string)
  (outer-fec :string)
  (id :string)
  (dump :string))

(defcfun ("gmsk_transfer_create_callback" gmsk-transfer-create-callback) :pointer
  "Initialize a new transfer using a callback."
  (radio-driver :string)
  (emit :unsigned-char)
  (data-callback :pointer)
  (callback-context :pointer)
  (sample-rate :unsigned-long)
  (bit-rate :unsigned-int)
  (frequency :unsigned-long)
  (frequency-offset :long)
  (gain :unsigned-int)
  (ppm :float)
  (inner-fec :string)
  (outer-fec :string)
  (id :string)
  (dump :string))

(defcfun ("gmsk_transfer_free" gmsk-transfer-free) :void
  "Cleanup after a finished transfer."
  (transfer :pointer))

(defcfun ("gmsk_transfer_start" gmsk-transfer-start) :void
  "Start a transfer and return when finished."
  (transfer :pointer))

(defcfun ("gmsk_transfer_stop" gmsk-transfer-stop) :void
  "Interrupt a transfer."
  (transfer :pointer))

(defcfun ("gmsk_transfer_stop_all" gmsk-transfer-stop-all) :void
  "Interrupt a transfer.")

(defcfun ("gmsk_transfer_print_available_radios"
          gmsk-transfer-print-available-radios)
  :void
  "Print list of detected software defined radios.")

(defcfun ("gmsk_transfer_print_available_forward_error_codes"
          gmsk-transfer-print-available-forward-error-codes)
  :void
  "Print list of supported forward error codes.")


;;;
;;; Lisp API
;;;

(defun verbosity ()
  "Get the verbosity level."
  (gmsk-transfer-is-verbose))

(defun (setf verbosity) (value)
  "Set the verbosity level."
  (gmsk-transfer-set-verbose value))

(defun make-transfer (&key
                        (radio-driver "") emit file data-callback
                        callback-context (sample-rate 2000000) (bit-rate 9600)
                        (frequency 434000000) (frequency-offset 0) (gain 0)
                        (ppm 0.0) (inner-fec "h128") (outer-fec "none") (id "")
                        dump)
  "Initialize a transfer."
  (when (or (and file data-callback)
            (and (not file) (not data-callback)))
    (error "Either FILE or DATA-CALLBACK must be specified."))
  (let ((transfer (if file
                      (gmsk-transfer-create radio-driver
                                            (if emit 1 0)
                                            file
                                            sample-rate
                                            bit-rate
                                            frequency
                                            frequency-offset
                                            gain
                                            ppm
                                            inner-fec
                                            outer-fec
                                            id
                                            (or dump
                                                (null-pointer)))
                      (gmsk-transfer-create-callback radio-driver
                                                     (if emit 1 0)
                                                     data-callback
                                                     (or callback-context
                                                         (null-pointer))
                                                     sample-rate
                                                     bit-rate
                                                     frequency
                                                     frequency-offset
                                                     gain
                                                     ppm
                                                     inner-fec
                                                     outer-fec
                                                     id
                                                     (or dump
                                                         (null-pointer))))))
    (if (null-pointer-p transfer)
        (error "Failed to initialize transfer.")
        transfer)))

(defun free-transfer (transfer)
  "Cleanup after a finished transfer."
  (gmsk-transfer-free transfer))

(defun start-transfer (transfer)
  "Start a transfer and return when finished."
  (gmsk-transfer-start transfer))

(defun stop-transfer (transfer)
  "Interrupt a transfer."
  (gmsk-transfer-stop transfer))

(defun stop-all-transfers ()
  "Interrupt all transfers."
  (gmsk-transfer-stop-all))

(defun transmit-file (file
                      &key
                        (radio-driver "") (sample-rate 2000000) (bit-rate 9600)
                        (frequency 434000000) (frequency-offset 0) (gain 0)
                        (ppm 0.0) (inner-fec "h128") (outer-fec "none") (id "")
                        dump)
  "Transmit the data from FILE."
  (let ((transfer (make-transfer :emit t
                                 :file file
                                 :radio-driver radio-driver
                                 :sample-rate sample-rate
                                 :bit-rate bit-rate
                                 :frequency frequency
                                 :frequency-offset frequency-offset
                                 :gain gain
                                 :ppm ppm
                                 :inner-fec inner-fec
                                 :outer-fec outer-fec
                                 :id id
                                 :dump dump)))
    (unwind-protect (gmsk-transfer-start transfer)
      (gmsk-transfer-free transfer))
    t))

(defun receive-file (file
                     &key
                       (radio-driver "") (sample-rate 2000000) (bit-rate 9600)
                       (frequency 434000000) (frequency-offset 0) (gain 0)
                       (ppm 0.0) (inner-fec "h128") (outer-fec "none") (id "")
                       dump)
  "Receive data into FILE."
  (let ((transfer (make-transfer :emit nil
                                 :file file
                                 :radio-driver radio-driver
                                 :sample-rate sample-rate
                                 :bit-rate bit-rate
                                 :frequency frequency
                                 :frequency-offset frequency-offset
                                 :gain gain
                                 :ppm ppm
                                 :inner-fec inner-fec
                                 :outer-fec outer-fec
                                 :id id
                                 :dump dump)))
    (unwind-protect (gmsk-transfer-start transfer)
      (gmsk-transfer-free transfer))
    t))

(defparameter *data-stream* nil)
(defparameter *buffer* nil)

(defcallback read-data-from-stream :int
    ((context :pointer)
     (payload :pointer)
     (payload-size :unsigned-int))
  (declare (ignore context))
  (handler-case
      (labels ((copy-data (total)
                 (let* ((size (min (length *buffer*) (- payload-size total)))
                        (n (read-sequence *buffer* *data-stream* :end size)))
                   (cond
                     ((zerop n)
                      (if (zerop total) -1 total))
                     (t
                      (dotimes (i n)
                        (setf (mem-aref payload :unsigned-char (+ total i))
                              (aref *buffer* i)))
                      (copy-data (+ total n)))))))
        (copy-data 0))
    (error () -1)))

(defcallback write-data-to-stream :int
    ((context :pointer)
     (payload :pointer)
     (payload-size :unsigned-int))
  (declare (ignore context))
  (handler-case
      (labels ((copy-data (total)
                 (let ((size (min (length *buffer*) (- payload-size total))))
                   (cond
                     ((zerop size)
                      payload-size)
                     (t
                      (dotimes (i size)
                        (setf (aref *buffer* i)
                              (mem-aref payload :unsigned-char (+ total i))))
                      (write-sequence *buffer* *data-stream* :end size)
                      (copy-data (+ total size)))))))
        (copy-data 0))
    (error () -1)))

(defun transmit-stream (stream
                        &key
                          (radio-driver "") (sample-rate 2000000)
                          (bit-rate 9600) (frequency 434000000)
                          (frequency-offset 0) (gain 0) (ppm 0.0)
                          (inner-fec "h128") (outer-fec "none") (id "")
                          dump)
  "Transmit the data from STREAM."
  (let* ((*data-stream* stream)
         (*buffer* (make-array 1024 :element-type '(unsigned-byte 8)))
         (transfer (make-transfer :emit t
                                  :data-callback (callback read-data-from-stream)
                                  :callback-context (null-pointer)
                                  :radio-driver radio-driver
                                  :sample-rate sample-rate
                                  :bit-rate bit-rate
                                  :frequency frequency
                                  :frequency-offset frequency-offset
                                  :gain gain
                                  :ppm ppm
                                  :inner-fec inner-fec
                                  :outer-fec outer-fec
                                  :id id
                                  :dump dump)))
    (unwind-protect (gmsk-transfer-start transfer)
      (gmsk-transfer-free transfer))
    t))

(defun receive-stream (stream
                       &key
                         (radio-driver "") (sample-rate 2000000)
                         (bit-rate 9600) (frequency 434000000)
                         (frequency-offset 0) (gain 0) (ppm 0.0)
                         (inner-fec "h128") (outer-fec "none") (id "")
                         dump)
  "Receive data to STREAM."
  (let* ((*data-stream* stream)
         (*buffer* (make-array 1024 :element-type '(unsigned-byte 8)))
         (transfer (make-transfer :emit nil
                                  :data-callback (callback write-data-to-stream)
                                  :callback-context (null-pointer)
                                  :radio-driver radio-driver
                                  :sample-rate sample-rate
                                  :bit-rate bit-rate
                                  :frequency frequency
                                  :frequency-offset frequency-offset
                                  :gain gain
                                  :ppm ppm
                                  :inner-fec inner-fec
                                  :outer-fec outer-fec
                                  :id id
                                  :dump dump)))
    (unwind-protect (gmsk-transfer-start transfer)
      (gmsk-transfer-free transfer))
    t))
