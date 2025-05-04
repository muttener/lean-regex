import RegexCorrectness.Backtracker.Compile
import RegexCorrectness.Backtracker.Refinement
import RegexCorrectness.Spec

set_option autoImplicit false

open Regex (NFA)
open Regex.Data (Expr CaptureGroups)
open Regex.Strategy (EquivMaterializedUpdate materializeRegexGroups materializeUpdates refineUpdateOpt refineUpdate)
open RegexCorrectness.Spec (SearchProblem)
open String (Iterator)

namespace Regex.Backtracker

-- TODO: needs to restate the main lemma
theorem captureNext_soundness {e bufferSize it matchedB}
  (disj : e.Disjoint)
  (hresB : captureNext (BufferStrategy bufferSize) (NFA.compile e) NFA.compile_wf it = .some matchedB) (v : it.Valid) :
  ∃ (it' it'' : Iterator) (groups : CaptureGroups),
    it'.toString = it.toString ∧
    it.pos ≤ it'.pos ∧
    e.Captures it' it'' groups ∧
    EquivMaterializedUpdate (materializeRegexGroups groups) matchedB := by
  sorry

theorem captureNext_completeness {e bufferSize it}
  (hresB : captureNext (BufferStrategy bufferSize) (NFA.compile e) NFA.compile_wf it = .none) (v : it.Valid) :
  ¬∃ (it' it'' : Iterator) (groups : CaptureGroups),
    it'.toString = it.toString ∧
    it.pos ≤ it'.pos ∧
    e.Captures it' it'' groups := by
  match hresH : captureNext HistoryStrategy (NFA.compile e) NFA.compile_wf it with
  | .some matchedH =>
    have ref := hresH ▸ hresB ▸ captureNext.refines (NFA.compile e) NFA.compile_wf bufferSize it
    simp [refineUpdateOpt] at ref
  | .none =>
    simp only [not_exists, not_and]
    exact captureNext.not_captures_of_none_compile hresH v

-- NOTE: we don't make this an instance because there are multiple decision procedures
def decideSearchProblem (e : Expr) (it : Iterator) (disj : e.Disjoint) (v : it.Valid) : Decidable (SearchProblem e it) :=
  match hresB : captureNext (BufferStrategy 0) (NFA.compile e) NFA.compile_wf it with
  | .some _ => .isTrue <|
    have ⟨it', it'', groups, eqs, le, c, _⟩ := captureNext_soundness disj hresB v
    ⟨it', it'', groups, eqs, le, c⟩
  | .none => .isFalse (captureNext_completeness hresB v)

-- TODO: remove
theorem captureNext_correct {e bufferSize it matchedB}
  (disj : e.Disjoint)
  (hresB : captureNext (BufferStrategy bufferSize) (NFA.compile e) NFA.compile_wf it = .some matchedB) (v : it.Valid) :
  ∃ it' it'' groups,
    it''.toString = it.toString ∧
    e.Captures it' it'' groups ∧
    EquivMaterializedUpdate (materializeRegexGroups groups) matchedB := by
  match hresH : captureNext HistoryStrategy (NFA.compile e) NFA.compile_wf it with
  | .some matchedH =>
    have ref := hresH ▸ hresB ▸ captureNext.refines (NFA.compile e) NFA.compile_wf bufferSize it
    simp [refineUpdateOpt, refineUpdate] at ref
    have ⟨it', it'', groups, eqstring, c, eqv⟩ := captureNext.capture_of_some_compile hresH v
    exact ⟨it', it'', groups, eqstring, c, ref ▸ eqv.materialize c disj⟩
  | .none =>
    have := hresH ▸ hresB ▸ captureNext.refines (NFA.compile e) NFA.compile_wf bufferSize it
    simp [refineUpdateOpt] at this

end Regex.Backtracker
