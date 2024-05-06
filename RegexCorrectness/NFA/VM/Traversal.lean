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

def LowerInvExploreεClosure (nfa : NFA) (next : SparseSet nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  ∀ i j : Fin nfa.nodes.size, i ∈ next → j.val ∈ nfa.εStep i →
    j ∈ next ∨ j = target ∨ .explore j ∈ stack

def LowerInvεClosure (nfa : NFA) (next : SparseSet nfa.nodes.size)
  (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  ∀ i j : Fin nfa.nodes.size, i ∈ next → j.val ∈ nfa.εStep i →
    j ∈ next ∨ .explore j ∈ stack

mutual
theorem lower_inv_exploreεClosure
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots'))
  (inv : LowerInvExploreεClosure nfa next target stack) :
  LowerInvεClosure nfa next' #[] := by
  unfold exploreεClosure at h
  split at h
  next hmem =>
    have inv' : LowerInvεClosure nfa next stack := by
      intro i j hi hj
      match inv i j hi hj with
      | .inl hnext => exact .inl hnext
      | .inr (.inl htarget) =>
        rw [←htarget] at hmem
        exact .inl hmem
      | .inr (.inr hstack) => exact .inr hstack
    exact lower_inv_εClosure h inv'
  next =>
    simp at h
    split at h
    next target' hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : LowerInvExploreεClosure nfa (next.insert target) ⟨target', isLt⟩ stack := by
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
      exact lower_inv_exploreεClosure h inv'
    next target₁ target₂ hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : LowerInvExploreεClosure nfa (next.insert target) ⟨target₁, isLt.1⟩ (stack.push (.explore ⟨target₂, isLt.2⟩)) := by
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
      exact lower_inv_exploreεClosure h inv'
    next _ target' hn =>
      have isLt := nfa.inBounds' target hn
      split at h
      next =>
        have inv' : LowerInvExploreεClosure nfa (next.insert target) ⟨target', isLt⟩ (stack.push (.restore currentSave)) := by
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
        exact lower_inv_exploreεClosure h inv'
      next =>
        have inv' : LowerInvExploreεClosure nfa (next.insert target) ⟨target', isLt⟩ stack := by
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
        exact lower_inv_exploreεClosure h inv'
    next hn =>
      have inv' : LowerInvεClosure nfa (next.insert target) stack := by
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
      exact lower_inv_εClosure h inv'
    next _ _ hn =>
      have inv' : LowerInvεClosure nfa (next.insert target) stack := by
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
      exact lower_inv_εClosure h inv'
    next hn =>
      have inv' : LowerInvεClosure nfa (next.insert target) stack := by
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
      exact lower_inv_εClosure h inv'
termination_by (next.measure, stack.size, 1)

theorem lower_inv_εClosure
  (h : εClosure nfa pos next currentSave matched saveSlots stack = (matched', next', saveSlots'))
  (inv : LowerInvεClosure nfa next stack) :
  LowerInvεClosure nfa next' #[] := by
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
      have inv' : LowerInvExploreεClosure nfa next target stack.pop := by
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
      exact lower_inv_exploreεClosure h inv'
    next _ _ heq =>
      have inv' : LowerInvεClosure nfa next stack.pop := by
        intro i j hi hj
        cases inv i j hi hj with
        | inl hnext => exact .inl hnext
        | inr hstack =>
          cases Array.mem_pop_or_eq_of_mem _ _ hemp hstack with
          | inl hstack => exact .inr hstack
          | inr heq' =>
            rw [heq] at heq'
            contradiction
      exact lower_inv_εClosure h inv'
termination_by (next.measure, stack.size, 0)
end

theorem εClosure_subset_lower_inv (inv : LowerInvεClosure nfa next #[]) :
  ∀ i ∈ next, ∀ j ∈ nfa.εClosure i, ∃ isLt : j < nfa.nodes.size, ⟨j, isLt⟩ ∈ next := by
  let S := { j | ∃ isLt : j < nfa.nodes.size, ⟨j, isLt⟩ ∈ next }
  have : ∀ i ∈ S, (_ : i < nfa.nodes.size) → ∀ j ∈ nfa[i].εStep, j ∈ S := by
    intro i hi iLt j hj
    have ⟨_, hi⟩ := hi
    have jLt : j < nfa.nodes.size := lt_of_εStep hj
    have hj : j ∈ nfa.εStep i := by
      simp [εStep, iLt, hj]
    have := inv ⟨i, iLt⟩ ⟨j, jLt⟩ hi hj
    simp at this
    refine ⟨jLt, this⟩
  have := mem_εStep_iff_εClosure_sub.mp this

  intro i hi j hj
  have : nfa.εClosure i ⊆ S := this i ⟨i.isLt, hi⟩
  have : j ∈ S := this hj
  exact this

def LowerBoundεClosure (nfa : NFA) (i : Fin nfa.nodes.size) (next next' : SparseSet nfa.nodes.size) : Prop :=
  ∀ j, j ∈ next ∨ j.val ∈ nfa.εClosure i → j ∈ next'

theorem lower_bound_exploreεClosure
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots'))
  (inv : LowerInvExploreεClosure nfa next target stack) :
  LowerBoundεClosure nfa target next next' := by
  intro j hj
  cases hj with
  | inl hnext => exact exploreεClosure_subset h j hnext
  | inr hcls =>
    have inv' := lower_inv_exploreεClosure h inv
    have ⟨_, hmem⟩ := εClosure_subset_lower_inv inv' target (target_mem_exploreεClosure h) j hcls
    exact hmem

def UpperInvExploreεClosure (nfa : NFA) (i : Fin nfa.nodes.size)
  (target : Fin nfa.nodes.size) (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  target.val ∈ nfa.εClosure i ∧ ∀ j, .explore j ∈ stack → j.val ∈ nfa.εClosure i

def UpperInvεClosure (nfa : NFA) (i : Fin nfa.nodes.size)
  (stack : Array (StackEntry nfa.nodes.size)) : Prop :=
  ∀ j, .explore j ∈ stack → j.val ∈ nfa.εClosure i

def UpperBoundεClosure (nfa : NFA) (i : Fin nfa.nodes.size) (next next' : SparseSet nfa.nodes.size) : Prop :=
  ∀ j ∈ next', j ∈ next ∨ j.val ∈ nfa.εClosure i

mutual
theorem upper_bound_exploreεClosure {i}
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target stack = (matched', next', saveSlots'))
  (inv : UpperInvExploreεClosure nfa i target stack) :
  UpperBoundεClosure nfa i next next' := by
  unfold exploreεClosure at h
  split at h
  next => exact upper_bound_εClosure h inv.2
  next =>
    suffices UpperBoundεClosure nfa i (next.insert target) next' by
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
      have inv' : UpperInvExploreεClosure nfa i ⟨target', isLt⟩ stack :=
        ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), inv.2⟩
      exact upper_bound_exploreεClosure h inv'
    next target₁ target₂ hn =>
      have isLt := nfa.inBounds' target hn
      have inv' : UpperInvExploreεClosure nfa i ⟨target₁, isLt.1⟩ (stack.push (.explore ⟨target₂, isLt.2⟩)) := by
        refine ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), ?_⟩
        intro j hj
        cases (Array.mem_push ..).mp hj with
        | inl hj => exact inv.2 j hj
        | inr hj =>
          simp at hj
          exact εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn, hj])
      exact upper_bound_exploreεClosure h inv'
    next _ target' hn =>
      have isLt := nfa.inBounds' target hn
      split at h
      next =>
        have inv' : UpperInvExploreεClosure nfa i ⟨target', isLt⟩ (stack.push (.restore currentSave)) := by
          refine ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), ?_⟩
          intro j hj
          cases (Array.mem_push ..).mp hj with
          | inl hj => exact inv.2 j hj
          | inr hj => contradiction
        exact upper_bound_exploreεClosure h inv'
      next =>
        have inv' : UpperInvExploreεClosure nfa i ⟨target', isLt⟩ stack :=
          ⟨εClosure_snoc inv.1 (by simp [εStep, Node.εStep, hn]), inv.2⟩
        exact upper_bound_exploreεClosure h inv'
    next hn => exact upper_bound_εClosure h inv.2
    next hn => exact upper_bound_εClosure h inv.2
    next hn => exact upper_bound_εClosure h inv.2
termination_by (next.measure, stack.size, 1)

theorem upper_bound_εClosure {i}
  (h : εClosure nfa pos next currentSave matched saveSlots stack = (matched', next', saveSlots'))
  (inv : UpperInvεClosure nfa i stack) :
  UpperBoundεClosure nfa i next next' := by
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
      have inv' : UpperInvExploreεClosure nfa i target stack.pop :=
        ⟨inv target (heq ▸ Array.mem_back' hemp), fun j hj => inv j (Array.mem_of_mem_pop _ _ hj)⟩
      exact upper_bound_exploreεClosure h inv'
    next =>
      have inv' : UpperInvεClosure nfa i stack.pop := fun j hj => inv j (Array.mem_of_mem_pop _ _ hj)
      exact upper_bound_εClosure h inv'
termination_by (next.measure, stack.size, 0)
end

theorem exploreεClosure_spec.mem_next_iff
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target #[] = (matched', next', saveSlots'))
  (inv : ∀ i j : Fin nfa.nodes.size, i ∈ next → j.val ∈ nfa.εStep i → j ∈ next) :
  ∀ i, i ∈ next' ↔ i ∈ next ∨ i.val ∈ nfa.εClosure target := by
  have lower_inv : LowerInvExploreεClosure nfa next target #[] := by
    intro i j hi hj
    exact .inl (inv i j hi hj)
  have upper_inv : UpperInvExploreεClosure nfa target target #[] := by
    refine ⟨.base, by intros; simp_all⟩
  have lower_bound := lower_bound_exploreεClosure h lower_inv
  have upper_bound := upper_bound_exploreεClosure h upper_inv
  intro i
  exact ⟨upper_bound i, lower_bound i⟩

theorem exploreεClosure_spec.preserve_cls
  (h : exploreεClosure nfa pos next currentSave matched saveSlots target #[] = (matched', next', saveSlots'))
  (inv : ∀ i j : Fin nfa.nodes.size, i ∈ next → j.val ∈ nfa.εStep i → j ∈ next) :
  ∀ i j : Fin nfa.nodes.size, i ∈ next' → j.val ∈ nfa.εStep i → j ∈ next' := by
  have lower_inv : LowerInvExploreεClosure nfa next target #[] := by
    intro i j hi hj
    exact .inl (inv i j hi hj)
  have lower_inv' : LowerInvεClosure nfa next' #[] := lower_inv_exploreεClosure h lower_inv
  simp [LowerInvεClosure] at lower_inv'
  exact lower_inv'

theorem stepChar_spec.mem_next_iff
  (h : stepChar nfa c pos next saveSlots target = (matched', next', saveSlots'))
  (inv : ∀ i j : Fin nfa.nodes.size, i ∈ next → j.val ∈ nfa.εStep i → j ∈ next) :
  ∀ j, j ∈ next' ↔ j ∈ next ∨ ∃ i ∈ nfa.charStep target c, j.val ∈ nfa.εClosure i := by
  unfold stepChar at h
  split at h
  next c' target' hn =>
    simp at hn
    split at h
    next hc =>
      simp at h
      have mem_next_iff := exploreεClosure_spec.mem_next_iff h inv

      intro j
      apply Iff.intro
      . intro hj
        cases (mem_next_iff j).mp hj with
        | inl hj => exact .inl hj
        | inr hj =>
          refine .inr ⟨target', ?_, hj⟩
          simp [charStep, Node.charStep, hn, hc]
      . intro hj
        cases hj with
        | inl hj => exact (mem_next_iff j).mpr (.inl hj)
        | inr hj =>
          simp [charStep, Node.charStep, hn, hc] at hj
          exact (mem_next_iff j).mpr (.inr hj)
    next hc =>
      have : ∀ i, ¬i ∈ nfa.charStep target c := by
        intro i
        simp [charStep, Node.charStep, hn, hc]
      simp at h
      simp [h, this]
  next hn =>
    have : ∀ i, ¬i ∈ nfa.charStep target c := by
      intro i
      simp at hn
      simp [charStep, Node.charStep, hn]
    simp at h
    simp [h, this]

theorem stepChar_spec.preserve_cls
  (h : stepChar nfa c pos next saveSlots target = (matched', next', saveSlots'))
  (inv : ∀ i j : Fin nfa.nodes.size, i ∈ next → j.val ∈ nfa.εStep i → j ∈ next) :
  ∀ i j : Fin nfa.nodes.size, i ∈ next' → j.val ∈ nfa.εStep i → j ∈ next' := by
  unfold stepChar at h
  split at h
  next =>
    split at h
    next =>
      simp at h
      exact exploreεClosure_spec.preserve_cls h inv
    next =>
      simp at h
      simp only [←h]
      exact inv
  next =>
    simp at h
    simp only [←h]
    exact inv

end NFA.VM
