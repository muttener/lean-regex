import Regex.Strategy
import RegexCorrectness.Backtracker.Basic
import RegexCorrectness.Backtracker.Path

set_option autoImplicit false

open Regex.Data (Span BoundedIterator)

namespace Regex.Backtracker.captureNextAux

section

variable {σ nfa wf it startIdx maxIdx visited stack}

theorem mem_of_mem_visited {s i} (hmem : visited.get s i) :
  (captureNextAux σ nfa wf startIdx maxIdx visited stack).2.get s i := by
  induction visited, stack using captureNextAux.induct' σ nfa wf startIdx maxIdx with
  | base visited => simp [captureNextAux_base, hmem]
  | visited visited update state it eq stack' mem ih => simp [captureNextAux_visited mem, ih hmem]
  | done visited update state it eq stack' mem hn => simp [captureNextAux_done mem hn, BitMatrix.get_set, hmem]
  | fail visited update state it eq stack' mem hn => simp [captureNextAux_fail mem hn, BitMatrix.get_set, hmem]
  | epsilon visited update state it eq stack' mem visited' state' hn ih =>
    rw [captureNextAux_epsilon mem hn]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | split visited update state it eq stack' mem visited' state₁ state₂ hn ih =>
    rw [captureNextAux_split mem hn]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | save visited update state it eq stack' mem visited' offset state' hn update' ih =>
    rw [captureNextAux_save mem hn]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | anchor_pos visited update state it eq stack' mem visited' a state' hn ht ih =>
    rw [captureNextAux_anchor_pos mem hn ht]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | anchor_neg visited update state it eq stack' mem visited' a state' hn ht ih =>
    rw [captureNextAux_anchor_neg mem hn ht]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | char_pos visited update state it eq stack' mem visited' c state' hn hnext hc ih =>
    rw [captureNextAux_char_pos mem hn hnext hc]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | char_neg visited update state it eq stack' mem visited' c state' hn hnext hc ih =>
    rw [captureNextAux_char_neg mem hn hnext hc]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | char_end visited update state it eq stack' mem visited' c state' hn hnext ih =>
    rw [captureNextAux_char_end mem hn hnext]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | sparse_pos visited update state it eq stack' mem visited' cs state' hn hnext hc ih =>
    rw [captureNextAux_sparse_pos mem hn hnext hc]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | sparse_neg visited update state it eq stack' mem visited' cs state' hn hnext hc ih =>
    rw [captureNextAux_sparse_neg mem hn hnext hc]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])
  | sparse_end visited update state it eq stack' mem visited' cs state' hn hnext ih =>
    rw [captureNextAux_sparse_end mem hn hnext]
    exact ih (by simp [visited', BitMatrix.get_set, hmem])

theorem mem_of_mem_top_stack {entry stack'} (hstack : entry :: stack' = stack) :
  (captureNextAux σ nfa wf startIdx maxIdx visited stack).2.get entry.state (entry.it.index' entry.eq) := by
  induction visited, stack using captureNextAux.induct' σ nfa wf startIdx maxIdx with
  | base visited => simp at hstack
  | visited visited update state it eq stack' mem ih =>
    simp [captureNextAux_visited mem]
    simp at hstack
    exact mem_of_mem_visited (by simp [hstack, mem])
  | done visited update state it eq stack' mem hn =>
    simp [captureNextAux_done mem hn]
    simp at hstack
    simp [hstack, BitMatrix.get_set]
  | fail visited update state it eq stack' mem hn =>
    simp [captureNextAux_fail mem hn]
    simp at hstack
    simp [hstack, BitMatrix.get_set]
  | epsilon visited update state it eq stack'' mem visited' state' hn ih =>
    rw [captureNextAux_epsilon mem hn]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | split visited update state it eq stack'' mem visited' state₁ state₂ hn ih =>
    rw [captureNextAux_split mem hn]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | save visited update state it eq stack' mem visited' offset state' hn update' ih =>
    rw [captureNextAux_save mem hn]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | anchor_pos visited update state it eq stack' mem visited' a state' hn ht ih =>
    rw [captureNextAux_anchor_pos mem hn ht]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | anchor_neg visited update state it eq stack' mem visited' a state' hn ht ih =>
    rw [captureNextAux_anchor_neg mem hn ht]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | char_pos visited update state it eq stack' mem visited' c state' hn hnext hc ih =>
    rw [captureNextAux_char_pos mem hn hnext hc]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | char_neg visited update state it eq stack' mem visited' c state' hn hnext hc ih =>
    rw [captureNextAux_char_neg mem hn hnext hc]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | char_end visited update state it eq stack' mem visited' c state' hn hnext ih =>
    rw [captureNextAux_char_end mem hn hnext]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | sparse_pos visited update state it eq stack' mem visited' cs state' hn hnext hc ih =>
    rw [captureNextAux_sparse_pos mem hn hnext hc]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | sparse_neg visited update state it eq stack' mem visited' cs state' hn hnext hc ih =>
    rw [captureNextAux_sparse_neg mem hn hnext hc]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])
  | sparse_end visited update state it eq stack' mem visited' cs state' hn hnext ih =>
    rw [captureNextAux_sparse_end mem hn hnext]
    simp at hstack
    exact mem_of_mem_visited (by simp [BitMatrix.get_set, hstack, mem])

end

/-
Here, we consider a minimal invariant enough to prove the "soundness" of the backtracker; a capture group found by the backtracker indeed corresponds to a match by the regex.
Therefore, we are only concenred about that the states in the stack are reachable from the start node starting from a particular position.

NOTE: if we want to show that the backtracker is complete (i.e., if the regex matches a string, then the backtracker will find a capture group), we need new invariants
about the visited set so that we can reason about the case the backtracker returns `.none`.

Current candidates are:

1. Closure under transition: ∀ (state, pos) ∈ visited, nfa.Step 0 state pos state' pos' → (state', pos') ∈ visited ∨ ∃ entry ∈ stack, entry.state = state' ∧ entry.it.poss = pos'
  * At the end of the traversal, we can use this invariant to show that the visited set is a reflexive-transitive closure of the step relation.
2. Upper bound of the visited set: ∀ (state, pos) ∈ visited, (state, pos) ∈ visisted₀ ∨ ∃ span, Path nfa wf l r span state update
  * We'll strengthen `UpperInv` to give an upper bound of the visited set.
  * Combined with the closure property, we can show that the traversal adds just the states reachable from the starting node at a particular position.
3. The visited set doesn't contain the `.done` state.
  * This implies that if the traversal returns `.none`, then there is no match starting from the particular position.
-/
section

variable {nfa wf startIdx maxIdx visited stack update' visited'}

structure UpperInv (wf : nfa.WellFormed) (l r : List Char) (stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)) where
  reachable : ∀ entry ∈ stack, ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update

theorem path_done_of_some {l r} (hres : captureNextAux HistoryStrategy nfa wf startIdx maxIdx visited stack = (.some update', visited'))
  (inv : UpperInv wf l r stack) :
  ∃ state span, nfa[state] = .done ∧ Path nfa wf l r span state update' := by
  induction visited, stack using captureNextAux.induct' HistoryStrategy nfa wf startIdx with
  | base visited => simp [captureNextAux_base] at hres
  | visited visited update state it eq stack' mem ih =>
    simp [captureNextAux_visited mem] at hres
    have inv' : UpperInv wf l r stack' := by
      have reachable entry (mem : entry ∈ stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update :=
        inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | done visited update state it eq stack' mem hn =>
    simp [captureNextAux_done mem hn] at hres
    have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
    exact ⟨state, span, hn, hres.1 ▸ path⟩
  | fail visited update state it eq stack' mem hn => simp [captureNextAux_fail mem hn] at hres
  | epsilon visited update state it eq stack' mem visited' state' hn ih =>
    rw [captureNextAux_epsilon mem hn] at hres
    have inv' : UpperInv wf l r (⟨update, state', it, eq⟩ :: stack') := by
      have reachable entry (mem : entry ∈ ⟨update, state', it, eq⟩ :: stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update := by
        simp at mem
        cases mem with
        | inl eq' =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          exact ⟨span, by simp [eqspan], path.more (.epsilon (Nat.zero_le _) state.isLt hn) (by simp)⟩
        | inr mem => exact inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | split visited update state it eq stack' mem visited' state₁ state₂ hn ih =>
    rw [captureNextAux_split mem hn] at hres
    let stack'' := ⟨update, state₁, it, eq⟩ :: ⟨update, state₂, it, eq⟩ :: stack'
    have inv' : UpperInv wf l r stack'' := by
      have reachable entry (mem : entry ∈ stack'') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update := by
        simp [stack''] at mem
        match mem with
        | .inl eq₁ =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          exact ⟨span, by simp [eqspan], path.more (.splitLeft (Nat.zero_le _) state.isLt hn) (by simp)⟩
        | .inr (.inl eq₂) =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          exact ⟨span, by simp [eqspan], path.more (.splitRight (Nat.zero_le _) state.isLt hn) (by simp)⟩
        | .inr (.inr mem) => exact inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | save visited update state it eq stack' mem visited' offset state' hn update' ih =>
    rw [captureNextAux_save mem hn] at hres
    have inv' : UpperInv wf l r (⟨update', state', it, eq⟩ :: stack') := by
      have reachable entry (mem : entry ∈ ⟨update', state', it, eq⟩ :: stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update := by
        simp at mem
        cases mem with
        | inl eq' =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          exact ⟨span, by simp [eqspan], path.more (.save (Nat.zero_le _) state.isLt hn) (by simp [update', HistoryStrategy, BoundedIterator.pos, ←eqspan, Span.curr_eq_pos])⟩
        | inr mem => exact inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | anchor_pos visited update state it eq stack' mem visited' a state' hn ht ih =>
    rw [captureNextAux_anchor_pos mem hn ht] at hres
    have inv' : UpperInv wf l r (⟨update, state', it, eq⟩ :: stack') := by
      have reachable entry (mem : entry ∈ ⟨update, state', it, eq⟩ :: stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update := by
        simp at mem
        cases mem with
        | inl eq' =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          exact ⟨span, by simp [eqspan], path.more (.anchor (Nat.zero_le _) state.isLt hn (eqspan ▸ ht)) (by simp)⟩
        | inr mem => exact inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | anchor_neg visited update state it eq stack' mem visited' a state' hn ht ih =>
    rw [captureNextAux_anchor_neg mem hn ht] at hres
    have inv' : UpperInv wf l r stack' := by
      have reachable entry (mem : entry ∈ stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update :=
        inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | char_pos visited update state it eq stack' mem visited' c state' hn hnext hc ih =>
    rw [captureNextAux_char_pos mem hn hnext hc] at hres
    have inv' : UpperInv wf l r (⟨update, state', it.next hnext, eq⟩ :: stack') := by
      have reachable entry (mem : entry ∈ ⟨update, state', it.next hnext, eq⟩ :: stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update := by
        simp at mem
        cases mem with
        | inl eq' =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          simp [BoundedIterator.hasNext, BoundedIterator.curr, ←eqspan] at hnext hc
          have ⟨r', eqr'⟩ := span.exists_cons_of_curr' hnext hc
          refine ⟨span.next, by simp [span.next_iterator eqr', eqspan, BoundedIterator.next, String.Iterator.next'_eq_next], ?_⟩
          simp
          have step : NFA.Step nfa 0 state span state' span.next .none := by
            simp [NFA.Step.iff_char hn, eqr', span.next_eq eqr']
          exact path.more step (by simp)
        | inr mem => exact inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | char_neg visited update state it eq stack' mem visited' c state' hn hnext hc ih =>
    rw [captureNextAux_char_neg mem hn hnext hc] at hres
    have inv' : UpperInv wf l r stack' := by
      have reachable entry (mem : entry ∈ stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update :=
        inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | char_end visited update state it eq stack' mem visited' c state' hn hnext ih =>
    rw [captureNextAux_char_end mem hn hnext] at hres
    have inv' : UpperInv wf l r stack' := by
      have reachable entry (mem : entry ∈ stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update :=
        inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | sparse_pos visited update state it eq stack' mem visited' cs state' hn hnext hc ih =>
    rw [captureNextAux_sparse_pos mem hn hnext hc] at hres
    have inv' : UpperInv wf l r (⟨update, state', it.next hnext, eq⟩ :: stack') := by
      have reachable entry (mem : entry ∈ ⟨update, state', it.next hnext, eq⟩ :: stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update := by
        simp at mem
        cases mem with
        | inl eq' =>
          subst entry
          have ⟨span, eqspan, path⟩ := inv.reachable ⟨update, state, it, eq⟩ (by simp)
          simp at eqspan path
          simp [BoundedIterator.hasNext, BoundedIterator.curr, ←eqspan] at hnext hc
          have ⟨r', eqr'⟩ := span.exists_cons_of_curr' hnext rfl
          refine ⟨span.next, by simp [span.next_iterator eqr', eqspan, BoundedIterator.next, String.Iterator.next'_eq_next], ?_⟩
          simp
          have step : NFA.Step nfa 0 state span state' span.next .none := by
            simp [NFA.Step.iff_sparse hn, eqr', span.next_eq eqr', hc]
          exact path.more step (by simp)
        | inr mem => exact inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | sparse_neg visited update state it eq stack' mem visited' cs state' hn hnext hc ih =>
    rw [captureNextAux_sparse_neg mem hn hnext hc] at hres
    have inv' : UpperInv wf l r stack' := by
      have reachable entry (mem : entry ∈ stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update :=
        inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'
  | sparse_end visited update state it eq stack' mem visited' cs state' hn hnext ih =>
    rw [captureNextAux_sparse_end mem hn hnext] at hres
    have inv' : UpperInv wf l r stack' := by
      have reachable entry (mem : entry ∈ stack') : ∃ span, span.iterator = entry.it.it ∧ Path nfa wf l r span entry.state entry.update :=
        inv.reachable entry (by simp [mem])
      exact ⟨reachable⟩
    exact ih hres inv'

end

end Regex.Backtracker.captureNextAux
