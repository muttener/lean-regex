import RegexCorrectness.NFA.Semantics.ProofData.Basic

set_option autoImplicit false

namespace Regex.NFA

namespace Compile.ProofData

namespace Group

variable [Group] {it it' update}

theorem castFromExpr (path : nfaExpr.Path nfaClose.nodes.size nfaExpr.start it nfaClose.start it' update) :
  nfa'.Path nfaClose.nodes.size nfaExpr.start it nfaClose.start it' update := by
  apply path.cast
  intro i _ lt
  exact ⟨Nat.lt_trans lt size_lt_expr', (get_lt_expr lt).symm⟩

theorem castToExpr {lb j} (wf : nfa.WellFormed) (next_lt : next < nfa.nodes.size)
  (path : nfa'.Path lb nfaExpr.start it j it' update) :
  nfaExpr.Path lb nfaExpr.start it j it' update := by
  have wf_expr := wf_expr wf next_lt
  apply path.cast' wf_expr.start_lt (Nat.le_of_lt size_lt_expr') wf_expr
  intro i _ lt
  exact get_lt_expr lt

end Group

namespace Alternate

variable [Alternate] {it it' update}

theorem castFrom₁ (path : nfa₁.Path nfa.nodes.size nfa₁.start it next it' update) :
  nfa'.Path nfa.nodes.size nfa₁.start it next it' update := by
  apply path.cast
  intro i _ lt
  exact ⟨Nat.lt_trans lt size_lt₁, (get_lt₁ lt).symm⟩

theorem castFrom₂ (path : nfa₂.Path nfa.nodes.size nfa₂.start it next it' update) :
  nfa'.Path nfa.nodes.size nfa₂.start it next it' update := by
  apply path.cast
  intro i _ lt
  exact ⟨Nat.lt_trans lt size_lt₂, (get_lt₂ lt).symm⟩

theorem castTo₁ (wf : nfa.WellFormed) (next_lt : next < nfa.nodes.size)
  (path : nfa'.Path nfa.nodes.size nfa₁.start it next it' update) :
  nfa₁.Path nfa.nodes.size nfa₁.start it next it' update := by
  have wf₁ := wf₁ wf next_lt
  apply path.cast' wf₁.start_lt (Nat.le_of_lt size_lt₁) wf₁
  intro i _ lt
  exact get_lt₁ lt

theorem castTo₂ {lb} (wf : nfa.WellFormed) (next_lt : next < nfa.nodes.size)
  (path : nfa'.Path lb nfa₂.start it next it' update) :
  nfa₂.Path lb nfa₂.start it next it' update := by
  have wf₂ := wf₂ wf next_lt
  apply path.cast' wf₂.start_lt (Nat.le_of_lt size_lt₂) wf₂
  intro i _ lt
  exact get_lt₂ lt

end Alternate

namespace Concat

variable [Concat] {it it' update}

theorem castFrom₂ (path : nfa₂.Path nfa.nodes.size nfa₂.start it next it' update) :
  nfa'.Path nfa.nodes.size nfa₂.start it next it' update := by
  apply path.cast
  intro i _ lt
  exact ⟨Nat.lt_trans lt size₂_lt, (get_lt₂ lt).symm⟩

theorem castTo₂ (wf : nfa.WellFormed) (next_lt : next < nfa.nodes.size)
  (path : nfa'.Path nfa.nodes.size nfa₂.start it next it' update) :
  nfa₂.Path nfa.nodes.size nfa₂.start it next it' update := by
  have wf₂ := wf₂ wf next_lt
  apply path.cast' wf₂.start_lt (Nat.le_of_lt size₂_lt) wf₂
  intro i _ lt
  exact get_lt₂ lt

end Concat

namespace Star

variable [Star] {it it' update}

theorem castFromExpr (path : nfaExpr.Path nfaPlaceholder.nodes.size nfaExpr.start it nfaPlaceholder.start it' update) :
  nfa'.Path nfaPlaceholder.nodes.size nfaExpr.start it nfaPlaceholder.start it' update := by
  apply path.cast
  intro i ge lt
  simp [nfaPlaceholder] at ge
  exact ⟨size_eq_expr' ▸ lt, (get_ne_start i (size_eq_expr' ▸ lt) (Nat.ne_of_gt ge)).symm⟩

theorem castToExpr (wf : nfa.WellFormed)
  (path : nfa'.Path nfaPlaceholder.nodes.size nfaExpr.start it nfaPlaceholder.start it' update) :
  nfaExpr.Path nfaPlaceholder.nodes.size nfaExpr.start it nfaPlaceholder.start it' update := by
  have wf_expr := wf_expr wf
  apply path.cast' wf_expr.start_lt (Nat.le_of_eq size_eq_expr'.symm) wf_expr
  intro i ge lt
  simp [nfaPlaceholder] at ge
  exact (get_ne_start i (size_eq_expr' ▸ lt) (Nat.ne_of_gt ge))

end Star

end Compile.ProofData

end Regex.NFA
