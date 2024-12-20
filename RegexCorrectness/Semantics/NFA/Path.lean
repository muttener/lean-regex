import Regex.NFA
import RegexCorrectness.NFA.Transition
import RegexCorrectness.Semantics.NFA.Heap
import RegexCorrectness.Semantics.NFA.Span

set_option autoImplicit false

/-
In this file, we treat an NFA as a collection of instructions and give a small-step operational semantics.
-/

-- TODO: maybe move this to `RegexCorrectness.NFA.Semantics`.
namespace Regex.NFA

open Semantics (Span Heap)

inductive Step (nfa : NFA) (lb : Nat) : Nat → Span → Heap → Nat → Span → Heap → Prop where
  | epsilon {i j span heap} (ge : lb ≤ i) (lt : i < nfa.nodes.size) (eq : nfa[i] = .epsilon j) :
    Step nfa lb i span heap j span heap
  | splitLeft {i j₁ j₂ span heap} (ge : lb ≤ i) (lt : i < nfa.nodes.size) (eq : nfa[i] = .split j₁ j₂) :
    Step nfa lb i span heap j₁ span heap
  | splitRight {i j₁ j₂ span heap} (ge : lb ≤ i) (lt : i < nfa.nodes.size) (eq : nfa[i] = .split j₁ j₂) :
    Step nfa lb i span heap j₂ span heap
  | save {i j span heap tag} (ge : lb ≤ i) (lt : i < nfa.nodes.size) (eq : nfa[i] = .save tag j) :
    Step nfa lb i span heap j span heap[tag := span.curr]
  | char {i j l m c r heap} (ge : lb ≤ i) (lt : i < nfa.nodes.size) (eq : nfa[i] = .char c j) :
    Step nfa lb i ⟨l, m, c :: r⟩ heap j ⟨l, c :: m, r⟩ heap
  | sparse {i j l m c r heap cs} (ge : lb ≤ i) (lt : i < nfa.nodes.size) (eq : nfa[i] = .sparse cs j) (mem : c ∈ cs):
    Step nfa lb i ⟨l, m, c :: r⟩ heap j ⟨l, c :: m, r⟩ heap

namespace Step

variable {nfa nfa' : NFA} {lb lb' i span heap j span' heap'}

theorem ge (step : nfa.Step lb i span heap j span' heap') : lb ≤ i := by
  cases step <;> assumption

theorem lt (step : nfa.Step lb i span heap j span' heap') : i < nfa.nodes.size := by
  cases step <;> assumption

theorem lt_right (wf : nfa.WellFormed) (step : nfa.Step lb i span heap j span' heap') : j < nfa.nodes.size := by
  have inBounds := wf.inBounds ⟨i, step.lt⟩
  cases step <;> simp_all [Node.inBounds]

theorem eq_left (step : nfa.Step lb i span heap j span' heap') : span'.l = span.l := by
  cases step <;> rfl

theorem cast (step : nfa.Step lb i span heap j span' heap')
  {lt : i < nfa'.nodes.size} (h : nfa[i]'step.lt = nfa'[i]) :
  nfa'.Step  lb i span heap j span' heap' := by
  cases step with
  | epsilon ge _ eq => exact .epsilon ge lt (h ▸ eq)
  | splitLeft ge _ eq => exact .splitLeft ge lt (h ▸ eq)
  | splitRight ge _ eq => exact .splitRight ge lt (h ▸ eq)
  | save ge _ eq => exact .save ge lt (h ▸ eq)
  | char ge _ eq => exact .char ge lt (h ▸ eq)
  | sparse ge _ eq mem => exact .sparse ge lt (h ▸ eq) mem

theorem liftBound' (ge : lb' ≤ i) (step : nfa.Step lb i span heap j span' heap') :
  nfa.Step lb' i span heap j span' heap' := by
  cases step with
  | epsilon _ lt eq => exact .epsilon ge lt eq
  | splitLeft _ lt eq => exact .splitLeft ge lt eq
  | splitRight _ lt eq => exact .splitRight ge lt eq
  | save _ lt eq => exact .save ge lt eq
  | char _ lt eq => exact .char ge lt eq
  | sparse _ lt eq mem => exact .sparse ge lt eq mem

theorem liftBound (le : lb' ≤ lb) (step : nfa.Step lb i span heap j span' heap') :
  nfa.Step lb' i span heap j span' heap' :=
  step.liftBound' (Nat.le_trans le step.ge)

theorem iff_done {lt : i < nfa.nodes.size} (eq : nfa[i] = .done) :
  nfa.Step lb i span heap j span' heap' ↔ False := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
  . simp

theorem iff_fail {lt : i < nfa.nodes.size} (eq : nfa[i] = .fail) :
  nfa.Step lb i span heap j span' heap' ↔ False := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
  . simp

theorem iff_epsilon {next} {lt : i < nfa.nodes.size} (eq : nfa[i] = .epsilon next) :
  nfa.Step lb i span heap j span' heap' ↔ lb ≤ i ∧ j = next ∧ span' = span ∧ heap' = heap := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
  . intro ⟨ge, hj, hspan, hheap⟩
    simp_all
    exact .epsilon ge lt eq

theorem iff_split {next₁ next₂} {lt : i < nfa.nodes.size} (eq : nfa[i] = .split next₁ next₂) :
  nfa.Step lb i span heap j span' heap' ↔ lb ≤ i ∧ (j = next₁ ∨ j = next₂) ∧ span' = span ∧ heap' = heap := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
  . intro ⟨ge, hj, hspan, hheap⟩
    cases hj with
    | inl hj =>
      simp_all
      exact .splitLeft ge lt eq
    | inr hj =>
      simp_all
      exact .splitRight ge lt eq

theorem iff_save {tag next} {lt : i < nfa.nodes.size} (eq : nfa[i] = .save tag next) :
  nfa.Step lb i span heap j span' heap' ↔ lb ≤ i ∧ j = next ∧ span' = span ∧ heap' = heap[tag := span.curr] := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
  . intro ⟨ge, hj, hspan, hheap⟩
    simp_all
    exact .save ge lt eq

theorem iff_char {c next} {lt : i < nfa.nodes.size} (eq : nfa[i] = .char c next) :
  nfa.Step lb i span heap j span' heap' ↔ ∃ r', span.r = c :: r' ∧ lb ≤ i ∧ j = next ∧ span' = ⟨span.l, c :: span.m, r'⟩ ∧ heap' = heap := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
  . intro ⟨r', hspan, ge, hj, hspan', hheap⟩
    simp_all
    have : span = ⟨span.l, span.m, c :: r'⟩ := by
      simp [←hspan]
    exact this ▸ .char ge lt eq

theorem iff_sparse {cs next} {lt : i < nfa.nodes.size} (eq : nfa[i] = .sparse cs next) :
  nfa.Step lb i span heap j span' heap' ↔ ∃ c r', span.r = c :: r' ∧ c ∈ cs ∧ lb ≤ i ∧ j = next ∧ span' = ⟨span.l, c :: span.m, r'⟩ ∧ heap' = heap := by
  apply Iff.intro
  . intro step
    cases step <;> simp_all
    next mem _ => exact ⟨_, _, ⟨rfl, rfl⟩, mem, rfl, rfl⟩
  . intro ⟨c, r', hspan, mem, ge, hj, hspan', hheap⟩
    simp_all
    have : span = ⟨span.l, span.m, c :: r'⟩ := by
      simp [←hspan]
    exact this ▸ .sparse ge lt eq mem

end Step

/--
A collection of steps in an NFA forms a path.
-/
inductive Path (nfa : NFA) (lb : Nat) : Nat → Span → Heap → Nat → Span → Heap → Prop where
  | last {i span heap j span' heap'} (step : Step nfa lb i span heap j span' heap') : Path nfa lb i span heap j span' heap'
  | more {i span heap j span' heap' k span'' heap''} (step : Step nfa lb i span heap j span' heap') (rest : Path nfa lb j span' heap' k span'' heap'') :
    Path nfa lb i span heap k span'' heap''

namespace Path

variable {nfa nfa' : NFA} {lb lb' i span heap j span' heap' k span'' heap''}

theorem ge (path : nfa.Path lb i span heap j span' heap') : lb ≤ i := by
  cases path with
  | last step => exact step.ge
  | more step => exact step.ge

theorem lt (path : nfa.Path lb i span heap j span' heap') : i < nfa.nodes.size := by
  cases path with
  | last step => exact step.lt
  | more step => exact step.lt

/--
A simpler casting procedure where the equality can be proven easily, e.g., when casting to a larger NFA.
-/
theorem cast (eq : ∀ i, lb ≤ i → (_ : i < nfa.nodes.size) → ∃ _ : i < nfa'.nodes.size, nfa[i] = nfa'[i])
  (path : nfa.Path lb i span heap j span' heap') :
  nfa'.Path lb i span heap j span' heap' := by
  induction path with
  | last step =>
    have ⟨_, eq⟩ := eq _ step.ge step.lt
    exact .last (step.cast eq)
  | more step _ ih =>
    have ⟨_, eq⟩ := eq _ step.ge step.lt
    exact .more (step.cast eq) ih

/--
A casting procedure that transports a path from a larger NFA to a smaller NFA.
-/
theorem cast' (lt : i < nfa.nodes.size) (size_le : nfa.nodes.size ≤ nfa'.nodes.size) (wf : nfa.WellFormed)
  (eq : ∀ i, lb ≤ i → (lt : i < nfa.nodes.size) → nfa'[i]'(Nat.lt_of_lt_of_le lt size_le) = nfa[i])
  (path : nfa'.Path lb i span heap j span' heap') :
  nfa.Path lb i span heap j span' heap' := by
  induction path with
  | last step => exact .last (step.cast (eq _ step.ge lt))
  | more step _ ih =>
    have step := step.cast (eq _ step.ge lt)
    have rest := ih (step.lt_right wf)
    exact .more step rest

theorem liftBound (le : lb' ≤ lb) (path : nfa.Path lb i span heap j span' heap') :
  nfa.Path lb' i span heap j span' heap' := by
  induction path with
  | last step => exact .last (step.liftBound le)
  | more step _ ih => exact .more (step.liftBound le) ih

theorem trans (path₁ : nfa.Path lb i span heap j span' heap') (path₂ : nfa.Path lb j span' heap' k span'' heap'') :
  nfa.Path lb i span heap k span'' heap'' := by
  induction path₁ with
  | last step => exact .more step path₂
  | more step _ ih => exact .more step (ih path₂)

end Path
