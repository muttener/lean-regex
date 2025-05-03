import Regex.Strategy
import RegexCorrectness.Data.BoundedIterator
import RegexCorrectness.Backtracker.Basic
import RegexCorrectness.Backtracker.Path

set_option autoImplicit false

open Regex.Data (BitMatrix BoundedIterator)
open String (Pos Iterator)
open Regex.NFA (Step)

namespace Regex.Backtracker.captureNextAux

section

variable {σ nfa wf it startIdx maxIdx visited stack}

theorem mem_of_mem_visited {s i} (hmem : visited.get s i) :
  (captureNextAux σ nfa wf startIdx maxIdx visited stack).2.get s i := by
  induction visited, stack using captureNextAux.induct' σ nfa wf startIdx maxIdx with
  | base visited => simp [captureNextAux_base, hmem]
  | visited visited update state it stack' mem ih => simp [captureNextAux_visited mem, ih hmem]
  | done visited update state it stack' mem hn => simp [captureNextAux_done mem hn, BitMatrix.get_set, hmem]
  | next visited update state it stack' mem hn ih =>
    rw [captureNextAux_next mem hn]
    exact ih (by simp [visited.get_set, hmem])

theorem mem_stack_top (entry stack') (hstack : entry :: stack' = stack) :
  (captureNextAux σ nfa wf startIdx maxIdx visited stack).2.get entry.state entry.it.index := by
  induction visited, stack using captureNextAux.induct' σ nfa wf startIdx maxIdx with
  | base visited => simp at hstack
  | visited visited update state it stack' mem =>
    simp [captureNextAux_visited mem]
    simp at hstack
    exact mem_of_mem_visited (by simp [hstack, mem])
  | done visited update state it stack' mem hn =>
    simp [captureNextAux_done mem hn]
    simp at hstack
    simp [hstack, BitMatrix.get_set]
  | next visited update state it stack' mem hn ih =>
    rw [captureNextAux_next mem hn]
    simp at hstack
    exact mem_of_mem_visited (by simp [visited.get_set, hstack])

end

/-
Here, we consider a minimal invariant enough to prove the "soundness" of the backtracker; a capture group found by the backtracker indeed corresponds to a match by the regex.
Therefore, we are only concenred about that the states in the stack are reachable from the start node starting from a particular position.

NOTE: if we want to show that the backtracker is complete (i.e., if the regex matches a string, then the backtracker will find a capture group), we need new invariants
about the visited set so that we can reason about the case the backtracker returns `.none`.

Current candidates are:

1. Closure under transition: ∀ (state, pos) ∈ visited, nfa.Step 0 state pos state' pos' → (state', pos') ∈ visited ∨ ∃ entry ∈ stack, entry.state = state' ∧ entry.it.poss = pos'
  * At the end of the traversal, we can use this invariant to show that the visited set is a reflexive-transitive closure of the step relation.
2. Upper bound of the visited set: ∀ (state, pos) ∈ visited, (state, pos) ∈ visisted₀ ∨ ∃ it, Path nfa wf it₀ it state update
  * We'll strengthen `UpperInv` to give an upper bound of the visited set.
  * Combined with the closure property, we can show that the traversal adds just the states reachable from the starting node at a particular position.
3. The visited set doesn't contain the `.done` state.
  * This implies that if the traversal returns `.none`, then there is no match starting from the particular position.
-/
section

variable {nfa : NFA} {wf : nfa.WellFormed} {startIdx maxIdx : Nat}
{visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)} {stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)} {update' visited'}

def StackInv (wf : nfa.WellFormed) (bit₀ : BoundedIterator startIdx maxIdx) (stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)) : Prop :=
  ∀ entry ∈ stack, Path nfa wf bit₀.it entry.it.it entry.state entry.update

namespace StackInv

theorem intro {bit₀ : BoundedIterator startIdx maxIdx} (v : bit₀.Valid) : StackInv wf bit₀ [⟨HistoryStrategy.empty, ⟨nfa.start, wf.start_lt⟩, bit₀⟩] := by
  simp [StackInv, HistoryStrategy]
  exact .init (BoundedIterator.valid_of_valid v)

theorem path {bit₀} {entry : StackEntry HistoryStrategy nfa startIdx maxIdx} {stack' : List (StackEntry HistoryStrategy nfa startIdx maxIdx)}
  (inv : StackInv wf bit₀ (entry :: stack')) :
  Path nfa wf bit₀.it entry.it.it entry.state entry.update := inv entry (by simp)

theorem isNextN {bit₀ : BoundedIterator startIdx maxIdx} {entry stack} (inv : StackInv wf bit₀ (entry :: stack)) : entry.it.IsNextNOf bit₀ :=
  (inv entry (by simp)).isNextNOf rfl

theorem preserves' {bit₀ entry stack'} (inv : StackInv wf bit₀ (entry :: stack')) (nextEntries) (hstack : stack = nextEntries ++ stack')
  (hnext : ∀ entry' ∈ nextEntries,
    ∃ update, nfa.Step 0 entry.state entry.it.it entry'.state entry'.it.it update ∧ entry'.update = List.append entry.update (List.ofOption update)) :
  StackInv wf bit₀ stack := by
  simp [hstack]
  intro entry' mem'
  simp at mem'
  cases mem' with
  | inl mem' =>
    have path := inv.path
    have ⟨update, step, hupdate⟩ := hnext entry' mem'
    exact path.more step hupdate
  | inr mem' => exact inv entry' (by simp [mem'])

theorem preserves {bit₀ stack' update state it} (inv : StackInv wf bit₀ (⟨update, state, it⟩ :: stack')) :
  StackInv wf bit₀ (pushNext HistoryStrategy nfa wf startIdx maxIdx stack' update state it) := by
  cases stack', update, state, it using pushNext.fun_cases' HistoryStrategy nfa wf startIdx maxIdx with
  | done stack' update state it hn =>
    rw [pushNext.done hn]
    exact inv.preserves' [] (by simp) (by simp)
  | fail stack' update state it hn =>
    rw [pushNext.fail hn]
    exact inv.preserves' [] (by simp) (by simp)
  | epsilon stack' update state it state' hn =>
    rw [pushNext.epsilon hn]
    apply inv.preserves' [⟨update, state', it⟩] (by simp)
    simp
    exact ⟨.none, .epsilon (Nat.zero_le _) state.isLt hn inv.path.validR, by simp⟩
  | split stack' update state it state₁ state₂ hn =>
    rw [pushNext.split hn]
    apply inv.preserves' [⟨update, state₁, it⟩, ⟨update, state₂, it⟩] (by simp)
    simp
    exact ⟨
      ⟨.none, .splitLeft (Nat.zero_le _) state.isLt hn inv.path.validR, by simp⟩,
      ⟨.none, .splitRight (Nat.zero_le _) state.isLt hn inv.path.validR, by simp⟩
    ⟩
  | save stack' update state it offset state' hn =>
    rw [pushNext.save hn]
    let update' := HistoryStrategy.write update offset it.pos
    apply inv.preserves' [⟨update', state', it⟩] (by simp [update'])
    simp
    exact ⟨.some (offset, it.pos), .save (Nat.zero_le _) state.isLt hn inv.path.validR, by simp [update', HistoryStrategy]⟩
  | anchor_pos stack' update state it a state' hn ht =>
    rw [pushNext.anchor_pos hn ht]
    apply inv.preserves' [⟨update, state', it⟩] (by simp)
    simp
    exact ⟨.none, .anchor (Nat.zero_le _) state.isLt hn inv.path.validR ht, by simp⟩
  | anchor_neg stack' update state it a state' hn ht =>
    rw [pushNext.anchor_neg hn ht]
    apply inv.preserves' [] (by simp) (by simp)
  | char_pos stack' update state it c state' hn hnext hc =>
    rw [pushNext.char_pos hn hnext hc]
    apply inv.preserves' [⟨update, state', it.next hnext⟩] (by simp)
    simp
    have ⟨l, r, vf⟩ := (it.valid_of_it_valid inv.path.validR).validFor_of_hasNext hnext
    exact ⟨.none, .char (Nat.zero_le _) state.isLt hn (hc ▸ vf), by simp⟩
  | char_neg stack' update state it c state' hn h =>
    rw [pushNext.char_neg hn h]
    apply inv.preserves' [] (by simp) (by simp)
  | sparse_pos stack' update state it cs state' hn hnext hc =>
    rw [pushNext.sparse_pos hn hnext hc]
    apply inv.preserves' [⟨update, state', it.next hnext⟩] (by simp)
    simp
    have ⟨l, r, vf⟩ := (it.valid_of_it_valid inv.path.validR).validFor_of_hasNext hnext
    exact ⟨.none, .sparse (Nat.zero_le _) state.isLt hn vf hc, by simp⟩
  | sparse_neg stack' update state it cs state' hn h =>
    rw [pushNext.sparse_neg hn h]
    apply inv.preserves' [] (by simp) (by simp)

end StackInv

theorem path_done_of_some {bit₀} (hres : captureNextAux HistoryStrategy nfa wf startIdx maxIdx visited stack = (.some update', visited'))
  (inv : StackInv wf bit₀ stack) :
  ∃ state it', nfa[state] = .done ∧ Path nfa wf bit₀.it it' state update' := by
  induction visited, stack using captureNextAux.induct' HistoryStrategy nfa wf startIdx with
  | base visited => simp [captureNextAux_base] at hres
  | visited visited update state it stack' mem ih =>
    simp [captureNextAux_visited mem] at hres
    have inv' : StackInv wf bit₀ stack' := inv.preserves' [] (by simp) (by simp)
    exact ih hres inv'
  | done visited update state it stack' mem hn =>
    simp [captureNextAux_done mem hn] at hres
    exact ⟨state, it.it, hn, hres.1 ▸ inv.path⟩
  | next visited update state it stack' mem hn ih =>
    simp [captureNextAux_next mem hn] at hres
    exact ih hres inv.preserves

end

section

variable {nfa : NFA} {wf : nfa.WellFormed} {startIdx maxIdx : Nat} {bit₀ : BoundedIterator startIdx maxIdx} {visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)} {stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)}

def ClosureInv (bit₀ : BoundedIterator startIdx maxIdx) (visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) (stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)) : Prop :=
  ∀ (state : Fin nfa.nodes.size) (bit : BoundedIterator startIdx maxIdx) (state' : Fin nfa.nodes.size) (bit' : BoundedIterator startIdx maxIdx) (update : Option (Nat × Pos)),
    bit.IsNextNOf bit₀ →
    visited.get state bit.index →
    nfa.Step 0 state bit.it state' bit'.it update →
    visited.get state' bit'.index ∨ ∃ entry ∈ stack, entry.state = state' ∧ entry.it = bit'

namespace ClosureInv

-- Preservation of the non-visited cases
theorem preserves' {entry stack'} (inv : ClosureInv bit₀ visited (entry :: stack)) (isNextN₀ : entry.it.IsNextNOf bit₀)
  (nextEntries : List (StackEntry HistoryStrategy nfa startIdx maxIdx)) (hstack : stack' = nextEntries ++ stack)
  (hnext : ∀ (state' : Fin nfa.nodes.size) (bit' : BoundedIterator startIdx maxIdx) (update : Option (Nat × Pos)),
    nfa.Step 0 entry.state entry.it.it state' bit'.it update →
    ∃ entry' ∈ nextEntries, entry'.state = state' ∧ entry'.it = bit') :
  ClosureInv bit₀ (visited.set entry.state entry.it.index) stack' := by
  intro state bit state' bit' update' isNextN hmem step
  simp [visited.get_set] at hmem
  match hmem with
  | .inl ⟨eqstate, eqindex⟩ =>
    -- There is a step from the top entry. Use the given property to find the next entries in the next stack top.
    have eqit : entry.it = bit := by
      simp [BoundedIterator.ext_index_iff, eqindex, isNextN.toString, isNextN₀.toString]
    have ⟨entry', hmem', eqstate', eqit'⟩ := hnext state' bit' update' (eqit ▸ eqstate ▸ step)
    exact .inr ⟨entry', by simp [hstack, hmem'], eqstate', eqit'⟩
  | .inr hmem =>
    -- There is a step from the entry below the stack top.
    match inv state bit state' bit' update' isNextN hmem step with
    | .inl hmem' => exact .inl (visited.get_set_of_get hmem')
    | .inr ⟨entry', hmem', eqstate, eqit⟩ =>
      simp at hmem'
      cases hmem' with
      | inl eq =>
        -- If the step moves to the top entry, then this iteration marks the entry as visited.
        simp [eq, ←eqstate, ←eqit, visited.get_set_eq]
      | inr hmem' =>
        -- If the step moves to the entry below the stack top, then the entry is still in the stack.
        exact .inr ⟨entry', by simp [hstack, hmem'], eqstate, eqit⟩

theorem preserves {stack update state it} (inv : ClosureInv bit₀ visited (⟨update, state, it⟩ :: stack)) (isNextN₀ : it.IsNextNOf bit₀) (hdone : nfa[state] ≠ .done) :
  ClosureInv bit₀ (visited.set state it.index) (pushNext HistoryStrategy nfa wf startIdx maxIdx stack update state it) := by
  cases stack, update, state, it using pushNext.fun_cases' HistoryStrategy nfa wf startIdx maxIdx with
  | done stack update state it hn => simp [hn] at hdone
  | fail stack update state it hn =>
    rw [pushNext.fail hn]
    apply inv.preserves' isNextN₀ [] (by simp)
    simp [Step.iff_fail hn]
  | epsilon stack' update state it state' hn =>
    rw [pushNext.epsilon hn]
    apply inv.preserves' isNextN₀ [⟨update, state', it⟩] (by simp)
    simp
    intro state'' bit'' update' step
    rw [Step.iff_epsilon hn] at step
    have ⟨_, eqstate'', eqit'', _⟩ := step
    simp [Fin.eq_of_val_eq eqstate'', BoundedIterator.ext_iff, eqit'']
  | split stack' update state it state₁ state₂ hn =>
    rw [pushNext.split hn]
    apply inv.preserves' isNextN₀ [⟨update, state₁, it⟩, ⟨update, state₂, it⟩] (by simp)
    simp
    intro state'' bit'' update' step
    rw [Step.iff_split hn] at step
    have ⟨_, eqstate'', eqit'', _⟩ := step
    simp [BoundedIterator.ext_iff, eqit'']
    cases eqstate'' with
    | inl eq₁ => simp [Fin.eq_of_val_eq eq₁]
    | inr eq₂ => simp [Fin.eq_of_val_eq eq₂]
  | save stack' update state it offset state' hn =>
    rw [pushNext.save hn]
    let update' := HistoryStrategy.write update offset it.pos
    apply inv.preserves' isNextN₀ [⟨update', state', it⟩] (by simp [update'])
    simp
    intro state'' bit'' update' step
    rw [Step.iff_save hn] at step
    have ⟨_, eqstate'', eqit'', _⟩ := step
    simp [Fin.eq_of_val_eq eqstate'', BoundedIterator.ext_iff, eqit'']
  | anchor_pos stack' update state it a state' hn ht =>
    rw [pushNext.anchor_pos hn ht]
    apply inv.preserves' isNextN₀ [⟨update, state', it⟩] (by simp)
    simp
    intro state'' bit'' update' step
    rw [Step.iff_anchor hn] at step
    have ⟨_, eqstate'', eqit'', _⟩ := step
    simp [Fin.eq_of_val_eq eqstate'', BoundedIterator.ext_iff, eqit'']
  | anchor_neg stack' update state it a state' hn ht =>
    rw [pushNext.anchor_neg hn ht]
    apply inv.preserves' isNextN₀ [] (by simp)
    simp [Step.iff_anchor hn, ht]
  | char_pos stack' update state it c state' hn hnext hc =>
    rw [pushNext.char_pos hn hnext hc]
    apply inv.preserves' isNextN₀ [⟨update, state', it.next hnext⟩] (by simp)
    simp
    intro state'' bit'' update' step
    rw [Step.iff_char hn] at step
    have ⟨l, r, _, eqstate'', eqit'', _, vf⟩ := step
    simp [Fin.eq_of_val_eq eqstate'', BoundedIterator.ext_iff, eqit'', BoundedIterator.next, Iterator.next'_eq_next]
  | char_neg stack' update state it c state' hn h =>
    rw [pushNext.char_neg hn h]
    apply inv.preserves' isNextN₀ [] (by simp)
    have (l r : List Char) : ¬it.it.ValidFor l (c :: r) := by
      intro vf
      simp [BoundedIterator.hasNext, BoundedIterator.curr, Iterator.curr'_eq_curr, vf.hasNext, vf.curr] at h
    simp [Step.iff_char hn, this]
  | sparse_pos stack' update state it cs state' hn hnext hc =>
    rw [pushNext.sparse_pos hn hnext hc]
    apply inv.preserves' isNextN₀ [⟨update, state', it.next hnext⟩] (by simp)
    simp
    intro state'' bit'' update' step
    rw [Step.iff_sparse hn] at step
    have ⟨l, c, r, _, eqstate'', eqit'', _, vf, hc'⟩ := step
    simp [Fin.eq_of_val_eq eqstate'', BoundedIterator.ext_iff, eqit'', BoundedIterator.next, Iterator.next'_eq_next]
  | sparse_neg stack' update state it cs state' hn h =>
    rw [pushNext.sparse_neg hn h]
    apply inv.preserves' isNextN₀ [] (by simp)
    have (l : List Char) (c : Char) (r : List Char) (vf : Iterator.ValidFor l (c :: r) it.it) : c ∉ cs := by
      simpa [BoundedIterator.hasNext, BoundedIterator.curr, Iterator.curr'_eq_curr, vf.hasNext, vf.curr] using h
    simp [Step.iff_sparse hn]
    intro state'' bit'' update' _ _ _
    exact this

end ClosureInv

/--
When the backtracker returns `.none`, it explores all reachable states and thus the visited set satisfies the closure property under the step relation.
-/
theorem step_closure {bit₀ : BoundedIterator startIdx maxIdx} {result} (hres : captureNextAux HistoryStrategy nfa wf startIdx maxIdx visited stack = result)
  (isNone : result.1 = .none)
  (cinv : ClosureInv bit₀ visited stack) (stinv : StackInv wf bit₀ stack) :
  ClosureInv bit₀ result.2 [] := by
  induction visited, stack using captureNextAux.induct' HistoryStrategy nfa wf startIdx maxIdx with
  | base visited =>
    simp [captureNextAux_base] at hres
    simp [←hres, cinv]
  | visited visited update state it stack' mem ih =>
    simp [captureNextAux_visited mem] at hres
    have cinv' : ClosureInv bit₀ visited stack' := by
      intro state₁ bit state₂ bit' update' isNextN hmem step
      match cinv state₁ bit state₂ bit' update' isNextN hmem step with
      | .inl hmem' => exact .inl hmem'
      | .inr ⟨entry, hmem', eqstate, eqit⟩ =>
        simp at hmem'
        cases hmem' with
        | inl eq => simp [eq, ←eqstate, ←eqit, mem]
        | inr hmem' => exact .inr ⟨entry, hmem', eqstate, eqit⟩
    exact ih hres cinv' (stinv.preserves' [] (by simp) (by simp))
  | done visited update state it stack' mem hn =>
    simp [captureNextAux_done mem hn] at hres
    simp [←hres] at isNone
  | next visited update state it stack' mem hn ih =>
    simp [captureNextAux_next mem hn] at hres
    exact ih hres (cinv.preserves stinv.isNextN hn) stinv.preserves

def StepClosure (bit₀ : BoundedIterator startIdx maxIdx) (visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) : Prop :=
  ∀ (state : Fin nfa.nodes.size) (bit : BoundedIterator startIdx maxIdx) (state' : Fin nfa.nodes.size) (bit' : BoundedIterator startIdx maxIdx) (update : Option (Nat × Pos)),
    bit.IsNextNOf bit₀ →
    visited.get state bit.index →
    nfa.Step 0 state bit.it state' bit'.it update →
    visited.get state' bit'.index

def PathClosure (bit₀ : BoundedIterator startIdx maxIdx) (visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) : Prop :=
  ∀ (state : Fin nfa.nodes.size) (bit : BoundedIterator startIdx maxIdx) (state' : Fin nfa.nodes.size) (bit' : BoundedIterator startIdx maxIdx) (update : List (Nat × Pos)),
    bit.IsNextNOf bit₀ →
    visited.get state bit.index →
    nfa.Path 0 state bit.it state' bit'.it update →
    visited.get state' bit'.index

theorem PathClosure.of_step_closure {bit₀ : BoundedIterator startIdx maxIdx} (wf : nfa.WellFormed) (h : StepClosure bit₀ visited) : PathClosure bit₀ visited := by
  let motive (i : Nat) (it : Iterator) : Prop :=
    ∃ (isLt : i < nfa.nodes.size) (bit : BoundedIterator startIdx maxIdx), bit.IsNextNOf bit₀ ∧ it = bit.it ∧ visited.get ⟨i, isLt⟩ bit.index
  have cls i it j it' update (base : motive i it) (step : nfa.Step 0 i it j it' update) : motive j it' := by
    have ⟨_, bit, isNextN, eqit, hmem⟩ := base

    have ge' : startIdx ≤ it'.pos.byteIdx :=
      calc startIdx
        _ ≤ it.pos.byteIdx := eqit ▸ bit.ge
        _ ≤ it'.pos.byteIdx := step.le_pos
    have le' : it'.pos.byteIdx ≤ maxIdx :=
      calc it'.pos.byteIdx
        _ ≤ it.toString.endPos.byteIdx := step.le_endPos
        _ = maxIdx := eqit ▸ bit.eq.symm
    have eq' : maxIdx = it'.toString.endPos.byteIdx :=
      calc maxIdx
        _ = it.toString.endPos.byteIdx := eqit ▸ bit.eq
        _ = it'.toString.endPos.byteIdx := by rw [step.toString_eq]
    let bit' : BoundedIterator startIdx maxIdx := ⟨it', ge', le', eq'⟩

    have isNextN' : bit'.IsNextNOf bit₀ := by
      match step.it_eq_or_next with
      | .inl eq =>
        have eq : bit' = bit := by
          simp [BoundedIterator.ext_iff, bit', ←eqit, eq]
        simpa [eq] using isNextN
      | .inr ⟨hnext, eq⟩ =>
        subst eqit
        have eq : bit' = bit.next hnext := by
          simp [BoundedIterator.ext_iff, bit', eq, BoundedIterator.next, Iterator.next'_eq_next]
        rw [eq]
        exact isNextN.next hnext
    have visited' := h ⟨i, step.lt⟩ bit ⟨j, step.lt_right wf⟩ bit' update isNextN hmem (by simp [←eqit, bit', step])
    exact ⟨step.lt_right wf, bit', isNextN', rfl, visited'⟩

  intro state bit state' bit' update isNextN hmem path
  have ⟨_, _, _, eqit, hmem'⟩ := path.of_step_closure motive cls ⟨state.isLt, bit, isNextN, rfl, hmem⟩
  exact (BoundedIterator.ext eqit) ▸ hmem'

/--
The closure property of the visited set can be lifted to paths.

Note: `nfa.Path` requires at least one step, so this is a transitive closure. However, the existence in the visited set
is obviously reflexive.
-/
theorem path_closure {bit₀ : BoundedIterator startIdx maxIdx} {result} (hres : captureNextAux HistoryStrategy nfa wf startIdx maxIdx visited stack = result)
  (isNone : result.1 = .none)
  (cinv : ClosureInv bit₀ visited stack) (stinv : StackInv wf bit₀ stack) :
  PathClosure bit₀ result.2 := by
  have cinv' : ClosureInv bit₀ result.2 [] := step_closure hres isNone cinv stinv
  have step_closure : StepClosure bit₀ result.2 := by
    intro state bit state' bit' update isNextN hmem step
    have := cinv' state bit state' bit' update isNextN hmem step
    simpa
  exact PathClosure.of_step_closure wf step_closure

end

section

variable {nfa : NFA} {wf : nfa.WellFormed} {startIdx maxIdx : Nat} {bit₀ : BoundedIterator startIdx maxIdx}
  {visited₀ visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)} {stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)}

def VisitedInv (wf : nfa.WellFormed) (bit₀ : BoundedIterator startIdx maxIdx) (visited₀ visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) : Prop :=
  ∀ (state : Fin nfa.nodes.size) (bit : BoundedIterator startIdx maxIdx),
    bit.IsNextNOf bit₀ →
    visited.get state bit.index →
    visited₀.get state bit.index ∨ ∃ update, Path nfa wf bit₀.it bit.it state update

namespace VisitedInv

theorem rfl {wf : nfa.WellFormed} {bit₀ : BoundedIterator startIdx maxIdx} : VisitedInv wf bit₀ visited₀ visited₀ := by
  intro state bit isNextN hmem
  exact .inl hmem

theorem preserves {bit : BoundedIterator startIdx maxIdx} {state : Fin nfa.nodes.size}
  (inv : VisitedInv wf bit₀ visited₀ visited)
  (isNextN : bit.IsNextNOf bit₀)
  (update : List (Nat × Pos)) (path : Path nfa wf bit₀.it bit.it state update) :
  VisitedInv wf bit₀ visited₀ (visited.set state bit.index) := by
  intro state' bit' isNextN' hmem
  simp [visited.get_set] at hmem
  match hmem with
  | .inl ⟨eqstate, eqindex⟩ =>
    have eqit : bit' = bit := by
      simp [BoundedIterator.ext_index_iff, eqindex, isNextN.toString, isNextN'.toString]
    simp [eqit, ←eqstate]
    exact .inr ⟨update, path⟩
  | .inr hmem =>
    have inv' := inv state' bit' isNextN' hmem
    simpa [visited.get_set] using inv'

end VisitedInv

-- mem_or_path_of_mem_of_none should be used for the starting stack.
theorem visited_inv_of_none {result} (hres : captureNextAux HistoryStrategy nfa wf startIdx maxIdx visited stack = result)
  (isNone : result.1 = .none)
  (vinv : VisitedInv wf bit₀ visited₀ visited) (stinv : StackInv wf bit₀ stack) :
  VisitedInv wf bit₀ visited₀ result.2 := by
  induction visited, stack using captureNextAux.induct' HistoryStrategy nfa wf startIdx maxIdx with
  | base visited =>
    simp [captureNextAux_base] at hres
    simp [←hres, vinv]
  | visited visited update state it stack' mem ih =>
    simp [captureNextAux_visited mem] at hres
    exact ih hres vinv (stinv.preserves' [] (by simp) (by simp))
  | done visited update state it stack' mem hn =>
    simp [captureNextAux_done mem hn] at hres
    simp [←hres] at isNone
  | next visited update state it stack' mem hn ih =>
    simp [captureNextAux_next mem hn] at hres
    have isNextN := stinv.isNextN
    have path := stinv ⟨update, state, it⟩ (by simp)
    exact ih hres (vinv.preserves isNextN update path) stinv.preserves

end

section

variable {nfa : NFA} {wf : nfa.WellFormed} {startIdx maxIdx : Nat} {visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)} {stack : List (StackEntry HistoryStrategy nfa startIdx maxIdx)}

def NotDoneInv (visited : BitMatrix nfa.nodes.size (maxIdx + 1 - startIdx)) : Prop :=
  ∀ (state : Fin nfa.nodes.size) (bit : BoundedIterator startIdx maxIdx),
    visited.get state bit.index →
    nfa[state] ≠ .done

theorem NotDoneInv.preserves {state} {bit : BoundedIterator startIdx maxIdx} (inv : NotDoneInv visited)
  (h : nfa[state] ≠ .done):
  NotDoneInv (visited.set state bit.index) := by
  intro state' bit' hmem
  simp [visited.get_set] at hmem
  match hmem with
  | .inl ⟨eqstate, eqindex⟩ => simpa [←eqstate] using h
  | .inr hmem => exact inv state' bit' hmem

theorem not_done_of_none {result} (hres : captureNextAux HistoryStrategy nfa wf startIdx maxIdx visited stack = result)
  (isNone : result.1 = .none)
  (inv : NotDoneInv visited) :
  NotDoneInv result.2 := by
  induction visited, stack using captureNextAux.induct' HistoryStrategy nfa wf startIdx maxIdx with
  | base visited =>
    simp [captureNextAux_base] at hres
    simp [←hres, inv]
  | visited visited update state it stack' mem ih =>
    simp [captureNextAux_visited mem] at hres
    exact ih hres inv
  | done visited update state it stack' mem hn =>
    simp [captureNextAux_done mem hn] at hres
    simp [←hres] at isNone
  | next visited update state it stack' mem hn ih =>
    simp [captureNextAux_next mem hn] at hres
    exact ih hres (inv.preserves hn)

end

end Regex.Backtracker.captureNextAux
