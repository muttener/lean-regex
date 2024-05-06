-- Correctness of the graph traversal implementations
import Regex.NFA.VM.Basic
import RegexCorrectness.NFA.Transition
import RegexCorrectness.NFA.VM.Array
import RegexCorrectness.NFA.VM.SparseSet
import Mathlib.Tactic

namespace NFA.VM

-- TODO: try function induciton with v4.8.0
mutual
theorem exploreεClosure_subset
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots')) :
  next ⊆ next' := by
  unfold exploreεClosure at h
  split at h
  next => exact εClosure_subset h
  next =>
    generalize hins : next.insert target = inserted at h
    have sub : next ⊆ inserted := hins ▸ SparseSet.subset_insert
    split at h <;> simp at h
    next => exact SparseSet.subset_trans sub (exploreεClosure_subset h)
    next => exact SparseSet.subset_trans sub (exploreεClosure_subset h)
    next => split at h <;> exact SparseSet.subset_trans sub (exploreεClosure_subset h)
    next => exact SparseSet.subset_trans sub (εClosure_subset h)
    next => exact SparseSet.subset_trans sub (εClosure_subset h)
    next => exact SparseSet.subset_trans sub (εClosure_subset h)
termination_by (next.measure, stack.size, 1)

theorem εClosure_subset
  (h : εClosure nfa pos next currentSave matched saveSlots stack = (matched', next', saveSlots')) :
  next ⊆ next' := by
  unfold εClosure at h
  split at h
  next =>
    have : next = next' := by
      simp at h
      simp only [h]
    exact this ▸ SparseSet.subset_self
  next =>
    simp at h
    have : stack.pop.size < stack.size := Array.lt_size_of_pop_of_not_empty _ (by assumption)
    split at h
    next => exact exploreεClosure_subset h
    next => exact εClosure_subset h
termination_by (next.measure, stack.size, 0)
end

theorem target_mem_exploreεClosure
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots')) :
  target ∈ next' := by
  unfold exploreεClosure at h
  split at h
  next hmem => exact εClosure_subset h target hmem
  next =>
    generalize hins : next.insert target = inserted at h
    have hmem : target ∈ inserted := hins ▸ SparseSet.mem_insert
    split at h <;> simp at h
    next => exact exploreεClosure_subset h target hmem
    next => exact exploreεClosure_subset h target hmem
    next => split at h <;> exact exploreεClosure_subset h target hmem
    next => exact εClosure_subset h target hmem
    next => exact εClosure_subset h target hmem
    next => exact εClosure_subset h target hmem

mutual
theorem mem_stack_mem_exploreεClosure
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots'))
  (hmem : .explore i ∈ stack) :
  i ∈ next' := by
  unfold exploreεClosure at h
  split at h
  next => exact mem_stack_mem_εClosure h hmem
  next =>
    simp at h
    split at h
    next => exact mem_stack_mem_exploreεClosure h hmem
    next => exact mem_stack_mem_exploreεClosure h ((Array.mem_push ..).mpr (.inl hmem))
    next =>
      split at h
      next => exact mem_stack_mem_exploreεClosure h ((Array.mem_push ..).mpr (.inl hmem))
      next => exact mem_stack_mem_exploreεClosure h hmem
    next => exact mem_stack_mem_εClosure h hmem
    next => exact mem_stack_mem_εClosure h hmem
    next => exact mem_stack_mem_εClosure h hmem
termination_by (next.measure, stack.size, 1)

theorem mem_stack_mem_εClosure
  (h : εClosure nfa pos next currentSave matched saveSlots stack = (matched', next', saveSlots'))
  (hmem : .explore i ∈ stack) :
  i ∈ next' := by
  unfold εClosure at h
  split at h
  next hemp =>
    have : stack = #[] := Array.isEmpty_iff.mp hemp
    subst this
    simp at hmem
  next hemp =>
    simp at h
    have : stack.pop.size < stack.size := Array.lt_size_of_pop_of_not_empty _ (by assumption)
    cases Array.mem_pop_or_eq_of_mem _ _ hemp hmem with
    | inl hmem =>
      split at h
      next => exact mem_stack_mem_exploreεClosure h hmem
      next => exact mem_stack_mem_εClosure h hmem
    | inr heq =>
      split at h
      next target heq' =>
        rw [heq'] at heq
        have : target = i := by
          simp at heq
          rw [heq]
        rw [this] at h
        exact target_mem_exploreεClosure h
      next _ heq' =>
        rw [heq'] at heq
        contradiction
termination_by (next.measure, stack.size, 0)
end

def lower_inv_exploreεClosure (nfa : NFA) (next : SparseSet nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  ∀ (i j : Fin nfa.nodes.size), i ∈ next → j.val ∈ nfa.εStep i →
    j ∈ next ∨ j = target ∨ .explore j ∈ stack

def lower_inv_εClosure (nfa : NFA) (next : SparseSet nfa.nodes.size)
  (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  ∀ (i j : Fin nfa.nodes.size), i ∈ next → j.val ∈ nfa.εStep i →
    j ∈ next ∨ .explore j ∈ stack

mutual
theorem lower_exploreεClosure
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots'))
  (inv : lower_inv_exploreεClosure nfa next target stack) :
  lower_inv_εClosure nfa next' #[] := by
  unfold exploreεClosure at h
  split at h
  next hmem =>
    have inv' : lower_inv_εClosure nfa next stack := by
      intro i j hi hj
      match inv i j hi hj with
      | .inl hnext => exact .inl hnext
      | .inr (.inl htarget) =>
        rw [←htarget] at hmem
        exact .inl hmem
      | .inr (.inr hstack) => exact .inr hstack
    exact lower_εClosure h inv'
  next =>
    simp at h
    split at h
    next target' hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : lower_inv_exploreεClosure nfa (next.insert target) ⟨target', isLt⟩ stack := by
        intro i j hi hj
        cases SparseSet.eq_or_mem_of_mem_insert hi with
        | inl htarget =>
          subst htarget
          simp [εStep, Node.εStep, hn] at hj
          exact .inr (.inl (Fin.eq_of_val_eq hj))
        | inr hnext =>
          match inv i j hnext hj with
          | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
          | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
          | .inr (.inr hstack) => exact .inr (.inr hstack)
      exact lower_exploreεClosure h inv'
    next target₁ target₂ hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : lower_inv_exploreεClosure nfa (next.insert target) ⟨target₁, isLt.1⟩ (stack.push (.explore ⟨target₂, isLt.2⟩)) := by
        intro i j hi hj
        cases SparseSet.eq_or_mem_of_mem_insert hi with
        | inl htarget =>
          subst htarget
          simp [εStep, Node.εStep, hn] at hj
          cases hj with
          | inl hj => exact .inr (.inl (Fin.eq_of_val_eq hj))
          | inr hj => exact .inr (.inr ((Array.mem_push ..).mpr (.inr (by simp [hj.symm]))))
        | inr hnext =>
          match inv i j hnext hj with
          | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
          | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
          | .inr (.inr hstack) => exact .inr (.inr ((Array.mem_push ..).mpr (.inl hstack)))
      exact lower_exploreεClosure h inv'
    next _ target' hn =>
      have isLt := nfa.inBounds' target hn
      split at h
      next =>
        have inv' : lower_inv_exploreεClosure nfa (next.insert target) ⟨target', isLt⟩ (stack.push (.restore currentSave)) := by
          intro i j hi hj
          cases SparseSet.eq_or_mem_of_mem_insert hi with
          | inl htarget =>
            subst htarget
            simp [εStep, Node.εStep, hn] at hj
            exact .inr (.inl (Fin.eq_of_val_eq hj))
          | inr hnext =>
            match inv i j hnext hj with
            | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
            | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
            | .inr (.inr hstack) => exact .inr (.inr ((Array.mem_push ..).mpr (.inl hstack)))
        exact lower_exploreεClosure h inv'
      next =>
        have inv' : lower_inv_exploreεClosure nfa (next.insert target) ⟨target', isLt⟩ stack := by
          intro i j hi hj
          cases SparseSet.eq_or_mem_of_mem_insert hi with
          | inl htarget =>
            subst htarget
            simp [εStep, Node.εStep, hn] at hj
            exact .inr (.inl (Fin.eq_of_val_eq hj))
          | inr hnext =>
            match inv i j hnext hj with
            | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
            | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
            | .inr (.inr hstack) => exact .inr (.inr hstack)
        exact lower_exploreεClosure h inv'
    next hn =>
      have inv' : lower_inv_εClosure nfa (next.insert target) stack := by
        intro i j hi hj
        cases SparseSet.eq_or_mem_of_mem_insert hi with
        | inl htarget =>
          subst htarget
          simp [εStep, Node.εStep, hn] at hj
        | inr hnext =>
          match inv i j hnext hj with
          | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
          | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
          | .inr (.inr hstack) => exact .inr hstack
      exact lower_εClosure h inv'
    next _ _ hn =>
      have inv' : lower_inv_εClosure nfa (next.insert target) stack := by
        intro i j hi hj
        cases SparseSet.eq_or_mem_of_mem_insert hi with
        | inl htarget =>
          subst htarget
          simp [εStep, Node.εStep, hn] at hj
        | inr hnext =>
          match inv i j hnext hj with
          | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
          | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
          | .inr (.inr hstack) => exact .inr hstack
      exact lower_εClosure h inv'
    next hn =>
      have inv' : lower_inv_εClosure nfa (next.insert target) stack := by
        intro i j hi hj
        cases SparseSet.eq_or_mem_of_mem_insert hi with
        | inl htarget =>
          subst htarget
          simp [εStep, Node.εStep, hn] at hj
        | inr hnext =>
          match inv i j hnext hj with
          | .inl hnext => exact .inl (SparseSet.mem_insert_of_mem hnext)
          | .inr (.inl htarget) => exact .inl (htarget ▸ SparseSet.mem_insert)
          | .inr (.inr hstack) => exact .inr hstack
      exact lower_εClosure h inv'
termination_by (next.measure, stack.size, 1)

theorem lower_εClosure
  (h : εClosure nfa pos next currentSave matched saveSlots stack = (matched', next', saveSlots'))
  (inv : lower_inv_εClosure nfa next stack) :
  lower_inv_εClosure nfa next' #[] := by
  unfold εClosure at h
  split at h
  next hemp =>
    have : stack = #[] := Array.isEmpty_iff.mp hemp
    subst this
    have : next = next' := by
      simp at h
      simp only [h]
    subst this
    exact inv
  next hemp =>
    simp at h
    have : stack.pop.size < stack.size := Array.lt_size_of_pop_of_not_empty _ (by assumption)
    split at h
    next _ target heq =>
      have inv' : lower_inv_exploreεClosure nfa next target stack.pop := by
        intro i j hi hj
        cases inv i j hi hj with
        | inl hnext => exact .inl hnext
        | inr hstack =>
          cases Array.mem_pop_or_eq_of_mem _ _ hemp hstack with
          | inl hstack => exact .inr (.inr hstack)
          | inr heq' =>
            rw [heq] at heq'
            have : j = target := by
              simp at heq'
              exact heq'
            exact .inr (.inl this)
      exact lower_exploreεClosure h inv'
    next _ _ heq =>
      have inv' : lower_inv_εClosure nfa next stack.pop := by
        intro i j hi hj
        cases inv i j hi hj with
        | inl hnext => exact .inl hnext
        | inr hstack =>
          cases Array.mem_pop_or_eq_of_mem _ _ hemp hstack with
          | inl hstack => exact .inr hstack
          | inr heq' =>
            rw [heq] at heq'
            contradiction
      exact lower_εClosure h inv'
termination_by (next.measure, stack.size, 0)
end

def upper_inv_exploreεClosure (nfa : NFA) (i : Fin nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  target.val ∈ nfa.εClosure i ∧ ∀ j, .explore j ∈ stack → j.val ∈ nfa.εClosure i

def upper_inv_εClosure (nfa : NFA) (i : Fin nfa.nodes.size)
  (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  ∀ j, .explore j ∈ stack → j.val ∈ nfa.εClosure i

def upper_statement (nfa : NFA) (i : Fin nfa.nodes.size) (next next' : SparseSet nfa.nodes.size) : Prop :=
  ∀ j ∈ next', j ∈ next ∨ j.val ∈ nfa.εClosure i

mutual
theorem upper_exploreεClosure {i}
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots'))
  (inv : upper_inv_exploreεClosure nfa i target stack) :
  upper_statement nfa i next next' := by
  unfold exploreεClosure at h
  split at h
  next => exact upper_εClosure h inv.2
  next =>
    suffices upper_statement nfa i (next.insert target) next' by
      intro j hj
      cases this j hj with
      | inl hnext =>
        cases SparseSet.eq_or_mem_of_mem_insert hnext with
        | inl heq => exact .inr (heq ▸ inv.1)
        | inr hnext => exact .inl hnext
      | inr hcls => exact .inr hcls

    simp at h
    split at h
    next target' hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : upper_inv_exploreεClosure nfa i ⟨target', isLt⟩ stack :=
        ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), inv.2⟩
      exact upper_exploreεClosure h inv'
    next target₁ target₂ hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : upper_inv_exploreεClosure nfa i ⟨target₁, isLt.1⟩ (stack.push (.explore ⟨target₂, isLt.2⟩)) := by
        refine ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), ?_⟩
        intro j hj
        cases (Array.mem_push ..).mp hj with
        | inl hj => exact inv.2 j hj
        | inr hj =>
          simp at hj
          exact εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn, hj])
      exact upper_exploreεClosure h inv'
    next _ target' hn =>
      have isLt := nfa.inBounds' target hn
      split at h
      next =>
        have inv' : upper_inv_exploreεClosure nfa i ⟨target', isLt⟩ (stack.push (.restore currentSave)) := by
          refine ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), ?_⟩
          intro j hj
          cases (Array.mem_push ..).mp hj with
          | inl hj => exact inv.2 j hj
          | inr hj => contradiction
        exact upper_exploreεClosure h inv'
      next =>
        have inv' : upper_inv_exploreεClosure nfa i ⟨target', isLt⟩ stack :=
          ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), inv.2⟩
        exact upper_exploreεClosure h inv'
    next hn => exact upper_εClosure h inv.2
    next hn => exact upper_εClosure h inv.2
    next hn => exact upper_εClosure h inv.2
termination_by (next.measure, stack.size, 1)

theorem upper_εClosure {i}
  (h : εClosure nfa pos next currentSave matched saveSlots stack = (matched', next', saveSlots'))
  (inv : upper_inv_εClosure nfa i stack) :
  upper_statement nfa i next next' := by
  unfold εClosure at h
  split at h
  next =>
    simp at h
    simp [h]
    intro j hj
    exact .inl hj
  next hemp =>
    simp at h
    have : stack.pop.size < stack.size := Array.lt_size_of_pop_of_not_empty _ (by assumption)
    split at h
    next target heq =>
      have inv' : upper_inv_exploreεClosure nfa i target stack.pop :=
        ⟨inv target (heq ▸ Array.mem_back' hemp), fun j hj => inv j (Array.mem_of_mem_pop _ _ hj)⟩
      exact upper_exploreεClosure h inv'
    next =>
      have inv' : upper_inv_εClosure nfa i stack.pop := fun j hj => inv j (Array.mem_of_mem_pop _ _ hj)
      exact upper_εClosure h inv'
termination_by (next.measure, stack.size, 0)
end

end NFA.VM
