import Regex.Regex
import RegexCorrectness.Data.Expr.Semantics
import RegexCorrectness.NFA.Compile
import RegexCorrectness.Syntax.Ast
import RegexCorrectness.VM

set_option autoImplicit false

open Regex.Data (Expr Span)
open String (Pos Iterator)
open Regex.NFA (EquivMaterializedUpdate materializeRegexGroups materializeUpdates)

namespace Regex

def IsSearchRegex (re : Regex) : Prop :=
  ∃ e : Expr,
    re.nfa = NFA.compile (.group 0 e) ∧
    Expr.Disjoint (.group 0 e) ∧
    re.maxTag = re.nfa.maxTag

namespace IsSearchRegex

theorem of_parse {s : String} {re : Regex} (h : Regex.parse s = .ok re) :
  IsSearchRegex re := by
  simp [Regex.parse, Regex.Syntax.Parser.parse] at h
  split at h
  next _ ast h' =>
    simp at h
    have ⟨e, eq⟩ := Regex.Syntax.Parser.Ast.toRegex_group_of_group ast
    have disj : Expr.Disjoint (.group 0 e) :=
      eq ▸ Regex.Syntax.Parser.Ast.toRegex_disjoint (.group ast)
    exact ⟨e, by simp [←h, eq], disj, by simp [←h]⟩
  next => simp at h

noncomputable def inner {re : Regex} (s : IsSearchRegex re) : Expr :=
  s.choose

noncomputable def expr {re : Regex} (s : IsSearchRegex re) : Expr :=
  .group 0 s.inner

theorem nfa_eq {re : Regex} (s : IsSearchRegex re) : re.nfa = NFA.compile s.expr :=
  s.choose_spec.1

theorem disj {re : Regex} (s : IsSearchRegex re) : Expr.Disjoint s.expr :=
  s.choose_spec.2.1

theorem maxTag_eq {re : Regex} (s : IsSearchRegex re) : re.maxTag = re.nfa.maxTag :=
  s.choose_spec.2.2

theorem le_maxTag {re : Regex} (s : IsSearchRegex re) : 1 ≤ re.maxTag := by
  simp [s.maxTag_eq]
  show 2 * 0 < re.nfa.maxTag
  apply NFA.lt_of_mem_tags_compile s.nfa_eq.symm
  simp [expr, Expr.tags]

theorem captures_of_captureNext {re bufferSize it matched} (h : VM.captureNext re.nfa re.wf bufferSize it = .some matched)
  (s : IsSearchRegex re) (v : it.Valid) (le : 2 ≤ bufferSize) :
  ∃ l m r groups,
    s.expr.Captures ⟨l, [], m ++ r⟩ ⟨l, m.reverse, r⟩ groups ∧
    EquivMaterializedUpdate (materializeRegexGroups groups) matched ∧
    matched[0] = .some ⟨String.utf8Len l⟩ ∧
    matched[1] = .some ⟨String.utf8Len l + String.utf8Len m⟩ := by
  have ⟨l, m, r, groups, c, eqv⟩ := VM.captureNext_correct s.nfa_eq.symm s.disj h v rfl
  simp at eqv
  refine ⟨l, m, r, groups, c, eqv, ?_⟩

  generalize hspan : (⟨l, [], m ++ r⟩ : Span) = span at c
  generalize hspan' : (⟨l, m.reverse, r⟩ : Span) = span' at c
  cases c with
  | @group _ _ groups' _ _ c' =>
    simp [materializeRegexGroups, EquivMaterializedUpdate] at eqv
    have eqv := eqv 0
    have h₁ : 0 < bufferSize := Nat.lt_of_lt_of_le (by decide) le
    have h₂ : 1 < bufferSize := Nat.lt_of_lt_of_le (by decide) le
    simp [←hspan, ←hspan', Span.curr, h₁, h₂] at eqv
    simp [←eqv]

theorem searchNext_some {re it first last} (h : VM.searchNext re.nfa re.wf it = .some (first, last))
  (s : IsSearchRegex re) (v : it.Valid) :
  ∃ l m r groups,
    s.expr.Captures ⟨l, [], m ++ r⟩ ⟨l, m.reverse, r⟩ groups ∧
    first = ⟨String.utf8Len l⟩ ∧
    last = ⟨String.utf8Len l + String.utf8Len m⟩ := by
  simp [VM.searchNext] at h
  generalize h' : VM.captureNext re.nfa re.wf 2 it = matched at h
  cases matched with
  | none => simp at h
  | some matched =>
    have ⟨l, m, r, groups, c, eqv, eq₁, eq₂⟩ := captures_of_captureNext h' s v (Nat.le_refl _)
    simp [eq₁, eq₂] at h
    exact ⟨l, m, r, groups, c, by simp [←h]⟩

end IsSearchRegex

end Regex
