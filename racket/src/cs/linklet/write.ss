
(define (linklet-virtual-machine-bytes)
  ;; #"chez-scheme"
  #vu8(99 104 101 122 45 115 99 104 101 109 101))

(define (write-linklet-bundle-hash ht dest-o)
  (let-values ([(ht cross-machine) (encode-linklet-paths ht)])
    (let ([bstr (if cross-machine
                    (cross-fasl-to-string cross-machine ht)
                    (let-values ([(o get) (open-bytevector-output-port)])
                      (fasl-write* ht o)
                      (get)))])
      (write-bytes (integer->integer-bytes (bytes-length bstr) 4 #f #f) dest-o)
      (write-bytes bstr dest-o))))

(define (encode-linklet-paths orig-ht)
  (let ([path->compiled-path (make-path->compiled-path 'write-linklet)])
    (let loop ([i (hash-iterate-first orig-ht)] [ht orig-ht] [cross-machine #f])
      (cond
       [(not i) (values ht cross-machine)]
       [else
        (let-values ([(key v) (hash-iterate-key+value orig-ht i)])
          (when (linklet? v) (check-fasl-preparation v))
          (let ([new-v (cond
                        [(linklet? v)
                         (cond
                          [(pair? (linklet-paths v))
                           (adjust-cross-perparation
                            (set-linklet-paths
                             v
                             (map path->compiled-path
                                  (linklet-paths v))))]
                          [else (adjust-cross-perparation v)])]
                        [else v])])
            (when (linklet? new-v)
              (linklet-pack-exports-info! new-v))
            (let ([new-ht (if (eq? v new-v)
                              ht
                              (hash-set ht key new-v))])
              (loop (hash-iterate-next orig-ht i)
                    new-ht
                    (or cross-machine
                        (and (linklet? v)
                             (let ([prep (linklet-preparation v)])
                               (and (pair? prep) (cdr prep)))))))))]))))

;; Before fasl conversion, change 'cross or 'faslable-unsafe to 'faslable
(define (adjust-cross-perparation l)
  (let ([p (linklet-preparation l)])
    (if (or (pair? p) (eq? p 'faslable-unsafe))
        (set-linklet-preparation l 'faslable)
        l)))

(define (check-fasl-preparation l)
  (case (linklet-preparation l)
    [(callable lazy)
     (raise-arguments-error 'write "linklet is not serializable")]))
