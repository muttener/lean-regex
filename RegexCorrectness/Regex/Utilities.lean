import RegexCorrectness.Regex.Captures

set_option autoImplicit false

namespace Regex

variable {re : Regex} {haystack : String}

theorem captures_of_capture_some {captured} (h : re.capture haystack = .some captured)
  (s : re.IsSearchRegex) :
  captured.Spec s := by
  simp [Regex.capture] at h
  have ⟨_, h⟩ := h
  have v := Captures.valid_captures haystack s
  exact (Captures.captures_of_next?_some h v).2

theorem captures_of_mem_captureAll.go {captures : Captures} {accum : Array CapturedGroups}
  (v : captures.Valid) (inv : ∀ captured ∈ accum, captured.Spec v.1) :
  ∀ captured ∈ captureAll.go captures accum, captured.Spec v.1 := by
  induction captures, accum using captureAll.go.induct with
  | case1 captures accum groups captures' next?_some ih =>
    -- next capture is found
    rw [captureAll.go, next?_some]
    simp
    have regex_eq := Captures.regex_eq_of_next?_some next?_some
    simp [regex_eq] at ih

    have ⟨v', spec⟩ := Captures.captures_of_next?_some next?_some v
    have inv' (captured : CapturedGroups) (h : captured ∈ accum.push groups) : captured.Spec v.1 := by
      simp [Array.push_eq_append_singleton] at h
      cases h with
      | inl mem => exact inv captured mem
      | inr eq => exact eq ▸ spec
    exact ih v' inv'
  | case2 captures accum next?_none =>
    -- next capture is not found
    rw [captureAll.go, next?_none]
    simp
    exact inv

theorem captures_of_mem_captureAll {captured} (mem : captured ∈ re.captureAll haystack)
  (s : re.IsSearchRegex) :
  captured.Spec s := by
  simp [Regex.captureAll] at mem
  have v := Captures.valid_captures haystack s
  exact captures_of_mem_captureAll.go v (by simp) captured mem

end Regex
