((:feature "type-model"
  :source-dirs ("src/type-model")
  :test-dir "t/type-model"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/type-model"
  :infra-package nil
  :depends-on ("syntax"))
 (:feature "registries"
  :source-dirs ("src/registries")
  :test-dir "t/registries"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/registries"
  :infra-package nil
  :depends-on ("type-model"))
 (:feature "quantities"
  :source-dirs ("src/quantities")
  :test-dir "t/quantities"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/quantities"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata" "syntax"))
 (:feature "type-level"
  :source-dirs ("src/type-level")
  :test-dir "t/type-level"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/type-level"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "hlist"
  :source-dirs ("src/hlist")
  :test-dir "t/hlist"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/hlist"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "rows"
  :source-dirs ("src/rows")
  :test-dir "t/rows"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/rows"
  :infra-package nil
  :depends-on ("type-model" "syntax"))
 (:feature "effects"
  :source-dirs ("src/effects")
  :test-dir "t/effects"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/effects"
  :infra-package nil
  :depends-on ("type-model" "registries" "syntax"))
 (:feature "subtyping"
  :source-dirs ("src/subtyping")
  :test-dir "t/subtyping"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/subtyping"
  :infra-package nil
  :depends-on ("type-model" "effects" "registries" "security-labels"))
 (:feature "syntax"
  :source-dirs ("src/syntax")
  :test-dir "t/syntax"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/syntax"
  :infra-package nil
  :depends-on ())
 (:feature "type-lowering"
  :source-dirs ("src/type-lowering")
  :test-dir "t/type-lowering"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/type-lowering"
  :infra-package nil
  :depends-on ("type-model" "subtyping" "registries" "quantities" "advanced-metadata" "syntax"))
 (:feature "unification"
  :source-dirs ("src/unification")
  :test-dir "t/unification"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/unification"
  :infra-package nil
  :depends-on ("type-model" "subtyping" "rows" "effects" "quantities" "registries" "advanced-metadata" "syntax"))
 (:feature "type-classes"
  :source-dirs ("src/type-classes")
  :test-dir "t/type-classes"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/type-classes"
  :infra-package nil
  :depends-on ("type-model" "unification" "syntax"))
 (:feature "inference"
  :source-dirs ("src/inference")
  :test-dir "t/inference"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/inference"
  :infra-package nil
  :depends-on ("type-model" "syntax" "type-lowering" "registries" "unification" "type-classes" "effects" "subtyping" "advanced-metadata" "channels" "actors" "coroutines" "stm" "simd" "concurrency" "ffi" "utility-types" "routing"))
 (:feature "checking"
  :source-dirs ("src/checking")
  :test-dir "t/checking"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/checking"
  :infra-package nil
  :depends-on ("type-model" "inference" "unification" "syntax"))
 (:feature "exhaustiveness"
  :source-dirs ("src/exhaustiveness")
  :test-dir "t/exhaustiveness"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/exhaustiveness"
  :infra-package nil
  :depends-on ("subtyping"))
 (:feature "utility-types"
  :source-dirs ("src/utility-types")
  :test-dir "t/utility-types"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/utility-types"
  :infra-package nil
  :depends-on ("type-model" "subtyping"))
 (:feature "generics"
  :source-dirs ("src/generics")
  :test-dir "t/generics"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/generics"
  :infra-package nil
  :depends-on ())
 (:feature "channels"
  :source-dirs ("src/channels")
  :test-dir "t/channels"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/channels"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "actors"
  :source-dirs ("src/actors")
  :test-dir "t/actors"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/actors"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "coroutines"
  :source-dirs ("src/coroutines")
  :test-dir "t/coroutines"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/coroutines"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "stm"
  :source-dirs ("src/stm")
  :test-dir "t/stm"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/stm"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "simd"
  :source-dirs ("src/simd")
  :test-dir "t/simd"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/simd"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "routing"
  :source-dirs ("src/routing")
  :test-dir "t/routing"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/routing"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata" "syntax"))
 (:feature "capabilities"
  :source-dirs ("src/capabilities")
  :test-dir "t/capabilities"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/capabilities"
  :infra-package nil
  :depends-on ())
 (:feature "concurrency"
  :source-dirs ("src/concurrency")
  :test-dir "t/concurrency"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/concurrency"
  :infra-package nil
  :depends-on ())
 (:feature "dependent"
  :source-dirs ("src/dependent")
  :test-dir "t/dependent"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/dependent"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "ffi"
  :source-dirs ("src/ffi")
  :test-dir "t/ffi"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/ffi"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "regions"
  :source-dirs ("src/regions")
  :test-dir "t/regions"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/regions"
  :infra-package nil
  :depends-on ("type-model"))
 (:feature "security-labels"
  :source-dirs ("src/security-labels")
  :test-dir "t/security-labels"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/security-labels"
  :infra-package nil
  :depends-on ("type-model" "advanced-metadata"))
 (:feature "units" :source-dirs ("src/units") :test-dir "t/units" :facade-packages ("cl-cc/type") :domain-package "cl-cc/type/units" :infra-package nil :depends-on ("type-model" "advanced-metadata"))
 (:feature "advanced-metadata"
  :source-dirs ("src/advanced-metadata")
  :test-dir "t/advanced-metadata"
  :facade-packages ("cl-cc/type")
  :domain-package "cl-cc/type/advanced-metadata"
  :infra-package nil
  :depends-on ("type-model" "registries" "syntax")))
