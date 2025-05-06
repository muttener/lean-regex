import RegexCorrectness.VM.Search.Basic

set_option autoImplicit false

open Regex.Data (SparseSet)
open Regex (NFA)
open String (Pos Iterator)

namespace Regex.VM

def MatchedInv (nfa : NFA) (wf : nfa.WellFormed) (it₀ : Iterator) (matched : Option (List (Nat × Pos))) : Prop :=
  (isSome : matched.isSome) →
    ∃ state it,
      nfa[state] = .done ∧
      nfa.VMPath wf it₀ it state (matched.get isSome)

theorem captureNext.go.inv {nfa wf it₀ it matched current next matched'}
  (h : captureNext.go HistoryStrategy nfa wf it matched current next = matched')
  (v : it.Valid) (eqs : it.toString = it₀.toString) (le : it₀.pos ≤ it.pos)
  (curr_inv : current.Inv nfa wf it₀ it) (empty : next.states.isEmpty)
  (matched_inv : MatchedInv nfa wf it₀ matched) :
  MatchedInv nfa wf it₀ matched' := by
  induction it, matched, current, next using captureNext.go.induct' HistoryStrategy nfa wf with
  | not_found it matched current next atEnd => simp_all
  | found it matched current next atEnd empty' some =>
    rw [captureNext.go_found atEnd empty' some] at h
    simp_all
  | ind_not_found it matched current next stepped expanded atEnd isNone₁ isNone₂ ih =>
    rw [captureNext.go_ind_not_found stepped expanded rfl rfl atEnd isNone₁ isNone₂] at h
    have le' : it₀.pos ≤ it.next.pos := Nat.le_trans le (Nat.le_of_lt it.lt_next)
    have v' : it.next.Valid := v.next (it.hasNext_of_not_atEnd atEnd)
    have next_inv : stepped.2.Inv nfa wf it₀ it.next := eachStepChar.inv_of_inv rfl v atEnd empty curr_inv
    have curr_inv' : expanded.2.Inv nfa wf it₀ it.next := εClosure.inv_of_inv rfl eqs le' v' next_inv
    have matched_inv' : MatchedInv nfa wf it₀ expanded.1 := by
      intro isSome
      have ⟨state, mem, hn, equpdate⟩ : ∃ i ∈ expanded.2.states, nfa[i] = .done ∧ expanded.2.updates[i] = expanded.1.get isSome :=
        εClosure.matched_inv rfl (by simp) isSome
      have ⟨update, path, write⟩ := curr_inv' state mem
      exact ⟨state, it.next, hn, by rw [←equpdate, write (by simp [εClosure.writeUpdate, hn])]; exact path⟩
    exact ih h v' eqs le' curr_inv' (by simp) matched_inv'
  | ind_found it matched current next stepped atEnd hemp isSome ih =>
    rw [captureNext.go_ind_found stepped rfl atEnd hemp isSome] at h
    have curr_inv' : stepped.2.Inv nfa wf it₀ it.next := eachStepChar.inv_of_inv rfl v atEnd empty curr_inv
    have matched_inv' : MatchedInv nfa wf it₀ (stepped.1 <|> matched) := by
      match h : stepped.1 with
      | .none => simpa using matched_inv
      | .some matched' =>
        simp
        have ⟨state, mem, hn, equpdate⟩ := eachStepChar.done_of_matched_some (matched' := stepped.1) (next' := stepped.2) rfl (by simp [h])
        have ⟨update, path, write⟩ := curr_inv' state mem
        intro _
        exact ⟨state, it.next, hn, by simpa [←h, ←equpdate, write (by simp [εClosure.writeUpdate, hn])] using path⟩
    exact ih h (v.next (it.hasNext_of_not_atEnd atEnd)) eqs (Nat.le_trans le (Nat.le_of_lt it.lt_next)) curr_inv' (by simp) matched_inv'

/--
If `captureNext` returns `some`, the returned list corresponds to the updates of a path from
`nfa.start` to a `.done` state.
-/
theorem captureNext.path_done_of_matched {nfa wf it₀ matched'}
  (h : captureNext HistoryStrategy nfa wf it₀ = matched') (v : it₀.Valid) (isSome' : matched'.isSome) :
  ∃ state it,
    nfa[state] = .done ∧
    nfa.VMPath wf it₀ it state (matched'.get isSome') := by
  simp [captureNext] at h

  set result := εClosure HistoryStrategy nfa wf it₀ .none ⟨.empty, Vector.mkVector nfa.nodes.size []⟩ [([], ⟨nfa.start, wf.start_lt⟩)]
  set matched := result.1
  set current := result.2
  have h' : result = (matched, current) := rfl
  have curr_inv : current.Inv nfa wf it₀ it₀ := εClosure.inv_of_inv h' rfl (Nat.le_refl _) v (.of_empty (by simp))
  have matched_inv : MatchedInv nfa wf it₀ matched := by
    intro isSome
    have ⟨state, mem, hn, hupdate⟩ := εClosure.matched_inv h' (by simp) isSome
    have ⟨update, path, write⟩ := curr_inv state mem
    simp [εClosure.writeUpdate, hn, hupdate] at write
    exact ⟨state, it₀, hn, write ▸ path⟩

  exact captureNext.go.inv h v rfl (Nat.le_refl _) curr_inv (by simp) matched_inv isSome'

end Regex.VM
