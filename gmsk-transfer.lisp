;;; This file is part of cl-gmsk-transfer
;;; Copyright 2021-2022 Guillaume LE VAILLANT
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
  (:import-from :cl-octet-streams
                #:with-octet-input-stream
                #:with-octet-output-stream)
  (:export #:free-transfer
           #:make-transfer
           #:start-transfer
           #:stop-all-transfers
           #:stop-transfer
           #:transmit-buffer
           #:transmit-file
           #:transmit-stream
           #:receive-buffer
           #:receive-callback
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
  (maximum-deviation :unsigned-int)
  (gain :string)
  (ppm :float)
  (bt :float)
  (inner-fec :string)
  (outer-fec :string)
  (id :string)
  (dump :string)
  (timeout :unsigned-int)
  (audio :unsigned-char))

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
  (maximum-deviation :unsigned-int)
  (gain :string)
  (ppm :float)
  (bt :float)
  (inner-fec :string)
  (outer-fec :string)
  (id :string)
  (dump :string)
  (timeout :unsigned-int)
  (audio :unsigned-char))

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
  (gmsk-transfer-set-verbose value)
  value)

(defun make-transfer (&key
                        (radio-driver "") emit file data-callback
                        callback-context (sample-rate 2000000) (bit-rate 9600)
                        (frequency 434000000) (frequency-offset 0) (gain 0)
                        (maximum-deviation (ceiling bit-rate 100))
                        (ppm 0.0) (bt 0.5) (inner-fec "h128") (outer-fec "none")
                        (id "") dump timeout audio)
  "Initialize a transfer."
  (when (or (and file data-callback)
            (and (not file) (not data-callback)))
    (error "Either FILE or DATA-CALLBACK must be specified."))
  (let ((transfer (if file
                      (gmsk-transfer-create radio-driver
                                            (if emit 1 0)
                                            (namestring file)
                                            sample-rate
                                            bit-rate
                                            frequency
                                            frequency-offset
                                            maximum-deviation
                                            (if (stringp gain)
                                                gain
                                                (format nil "~d" gain))
                                            ppm
                                            bt
                                            inner-fec
                                            outer-fec
                                            id
                                            (if dump
                                                (namestring dump)
                                                (null-pointer))
                                            (or timeout 0)
                                            (if audio 1 0))
                      (gmsk-transfer-create-callback radio-driver
                                                     (if emit 1 0)
                                                     data-callback
                                                     (or callback-context
                                                         (null-pointer))
                                                     sample-rate
                                                     bit-rate
                                                     frequency
                                                     frequency-offset
                                                     maximum-deviation
                                                     (if (stringp gain)
                                                         gain
                                                         (format nil "~d" gain))
                                                     ppm
                                                     bt
                                                     inner-fec
                                                     outer-fec
                                                     id
                                                     (if dump
                                                         (namestring dump)
                                                         (null-pointer))
                                                     (or timeout 0)
                                                     (if audio 1 0)))))
    (if (null-pointer-p transfer)
        (error "Failed to initialize transfer.")
        transfer)))

(defun free-transfer (transfer)
  "Cleanup after a finished transfer."
  (gmsk-transfer-free transfer))

(defun start-transfer (transfer)
  "Start a transfer and return when finished."
  (float-features:with-float-traps-masked t
    (gmsk-transfer-start transfer)))

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
                        (ppm 0.0) (bt 0.5) (inner-fec "h128") (outer-fec "none")
                        (id "") dump audio (final-delay 0.0))
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
                                 :bt bt
                                 :inner-fec inner-fec
                                 :outer-fec outer-fec
                                 :id id
                                 :dump dump
                                 :audio audio)))
    (unwind-protect
         (progn
           (start-transfer transfer)
           (unless (zerop final-delay)
             (sleep final-delay)))
      (free-transfer transfer))
    t))

(defun receive-file (file
                     &key
                       (radio-driver "") (sample-rate 2000000) (bit-rate 9600)
                       (frequency 434000000) (frequency-offset 0) (gain 0)
                       (maximum-deviation (ceiling bit-rate 100))
                       (ppm 0.0) (bt 0.5) (inner-fec "h128") (outer-fec "none")
                       (id "") dump timeout audio)
  "Receive data into FILE."
  (let ((transfer (make-transfer :emit nil
                                 :file file
                                 :radio-driver radio-driver
                                 :sample-rate sample-rate
                                 :bit-rate bit-rate
                                 :frequency frequency
                                 :frequency-offset frequency-offset
                                 :maximum-deviation maximum-deviation
                                 :gain gain
                                 :ppm ppm
                                 :bt bt
                                 :inner-fec inner-fec
                                 :outer-fec outer-fec
                                 :id id
                                 :dump dump
                                 :timeout timeout
                                 :audio audio)))
    (unwind-protect (start-transfer transfer)
      (free-transfer transfer))
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
                          (frequency-offset 0) (gain 0) (ppm 0.0) (bt 0.5)
                          (inner-fec "h128") (outer-fec "none") (id "")
                          dump audio (final-delay 0.0))
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
                                  :bt bt
                                  :inner-fec inner-fec
                                  :outer-fec outer-fec
                                  :id id
                                  :dump dump
                                  :audio audio)))
    (unwind-protect
         (progn
           (start-transfer transfer)
           (unless (zerop final-delay)
             (sleep final-delay)))
      (free-transfer transfer))
    t))

(defun receive-stream (stream
                       &key
                         (radio-driver "") (sample-rate 2000000)
                         (bit-rate 9600) (frequency 434000000)
                         (frequency-offset 0) (gain 0) (ppm 0.0) (bt 0.5)
                         (maximum-deviation (ceiling bit-rate 100))
                         (inner-fec "h128") (outer-fec "none") (id "")
                         dump timeout audio)
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
                                  :maximum-deviation maximum-deviation
                                  :gain gain
                                  :ppm ppm
                                  :bt bt
                                  :inner-fec inner-fec
                                  :outer-fec outer-fec
                                  :id id
                                  :dump dump
                                  :timeout timeout
                                  :audio audio)))
    (unwind-protect (start-transfer transfer)
      (free-transfer transfer))
    t))

(defun transmit-buffer (buffer
                        &key
                          (start 0) end (radio-driver "") (sample-rate 2000000)
                          (bit-rate 9600) (frequency 434000000)
                          (frequency-offset 0) (gain 0) (ppm 0.0) (bt 0.5)
                          (inner-fec "h128") (outer-fec "none") (id "")
                          dump audio (final-delay 0.0))
  "Transmit the data between START and END in BUFFER."
  (with-octet-input-stream (stream buffer start (or end (length buffer)))
    (transmit-stream stream
                     :radio-driver radio-driver
                     :sample-rate sample-rate
                     :bit-rate bit-rate
                     :frequency frequency
                     :frequency-offset frequency-offset
                     :gain gain
                     :ppm ppm
                     :bt bt
                     :inner-fec inner-fec
                     :outer-fec outer-fec
                     :id id
                     :dump dump
                     :audio audio
                     :final-delay final-delay)))

(defun receive-buffer (&key
                         (radio-driver "") (sample-rate 2000000)
                         (bit-rate 9600) (frequency 434000000)
                         (frequency-offset 0) (gain 0) (ppm 0.0) (bt 0.5)
                         (maximum-deviation (ceiling bit-rate 100))
                         (inner-fec "h128") (outer-fec "none") (id "")
                         dump timeout audio)
  "Receive data into a new octet vector and return it."
  (with-octet-output-stream (stream)
    (receive-stream stream
                    :radio-driver radio-driver
                    :sample-rate sample-rate
                    :bit-rate bit-rate
                    :frequency frequency
                    :frequency-offset frequency-offset
                    :maximum-deviation maximum-deviation
                    :gain gain
                    :ppm ppm
                    :bt bt
                    :inner-fec inner-fec
                    :outer-fec outer-fec
                    :id id
                    :dump dump
                    :timeout timeout
                    :audio audio)))

(defparameter *user-function* nil)

(defcallback call-user-function :int
    ((context :pointer)
     (payload :pointer)
     (payload-size :unsigned-int))
  (declare (ignore context))
  (handler-case
      (let ((data (make-array payload-size :element-type '(unsigned-byte 8))))
        (dotimes (i payload-size)
          (setf (aref data i) (mem-aref payload :unsigned-char i)))
        (funcall *user-function* data)
        payload-size)
    (error () -1)))

(defun receive-callback (function
                         &key
                           (radio-driver "") (sample-rate 2000000)
                           (bit-rate 9600) (frequency 434000000)
                           (frequency-offset 0) (gain 0) (ppm 0.0) (bt 0.5)
                           (maximum-deviation (ceiling bit-rate 100))
                           (inner-fec "h128") (outer-fec "none") (id "")
                           dump timeout audio)
  "Receive data and call a FUNCTION on it. The FUNCTION must take one octet
vector as argument."
  (let* ((*user-function* function)
         (transfer (make-transfer :emit nil
                                  :data-callback (callback call-user-function)
                                  :callback-context (null-pointer)
                                  :radio-driver radio-driver
                                  :sample-rate sample-rate
                                  :bit-rate bit-rate
                                  :frequency frequency
                                  :frequency-offset frequency-offset
                                  :maximum-deviation maximum-deviation
                                  :gain gain
                                  :ppm ppm
                                  :bt bt
                                  :inner-fec inner-fec
                                  :outer-fec outer-fec
                                  :id id
                                  :dump dump
                                  :timeout timeout
                                  :audio audio)))
    (unwind-protect (start-transfer transfer)
      (free-transfer transfer))
    t))
