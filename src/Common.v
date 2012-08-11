Require Export String. 
(* Require Vector.  *)

Definition bind {A B: Type} (f: option A) (g: A -> option B) : option B :=
  match f with
    | Some x => g x
    | None => None
  end.

Definition bind2 {A B C: Type} (f: option (A * B)) (g: A -> B -> option C) : option C :=
  match f with
  | Some (x, y) => g x y
  | None => None
  end.

Remark bind_inversion:
  forall (A B: Type) (f: option A) (g: A -> option B) (y: B),
  bind f g = Some y ->
  exists x, f = Some x /\ g x = Some y.
Proof. 
  intros; destruct f.  simpl in H.
  exists a; auto. 
  discriminate. 
Qed. 

Notation "'do' X <- A ; B" := (bind A (fun X => B) )
  (at level 200, X ident, A at level 100, B at level 200). 

Notation "'do' ( X , Y ) <- A ; B" := (bind2 A (fun X Y => B))
 (at level 200, X ident, Y ident, A at level 100, B at level 200).

Notation "'check' A ; B" := (if A then B else None)
  (at level 200, A at level 100, B at level 200). 

Ltac invert_do H :=
  match type of H with
    | (Some _ = Some _) =>
        inversion H; clear H; try subst
    | (None = Some _) =>
        discriminate
    | (bind ?F ?G = Some ?X) => 
        let x := fresh "x" in
          let EQ1 := fresh "EQ" in
            let EQ2 := fresh "EQ" in
              destruct (bind_inversion _ _ F G _ H) as [x [EQ1 EQ2]];
        clear H;
        try (invert_do EQ2)
  end. 
  
Axiom admit : forall {X} , X. 

Definition ident := string. 

Definition comp {A B C} (f : B -> C) (g : A -> B) := fun (x : A) => f (g (x)). 
Notation "f ∘ g" := (comp f g) (at level 40).

Notation "[ ]" := nil : list_scope.
Notation "t :: q" := (cons t q) : list_scope. 
Notation "[ a ; .. ; b ]" := (a :: .. (b :: []) ..)%list : list_scope.

Section var.   
  Variable T : Type. 

  Inductive var : list T -> T -> Type :=
  | var_0 : forall E t , var (cons t E) t
  | var_S : forall E t t' , var E t' -> var (cons t E) t'. 


  Fixpoint var_lift E F t (v : var E t) : var (E++F) t :=
    match v with 
        var_0 E' t'=> var_0 (E' ++ F) t'
      | var_S E' s' s'' v' => var_S (E' ++ F ) s' s'' (var_lift E' F s'' v') 
    end. 
  
  Fixpoint var_to_nat {l t} (v : var l t) : nat :=
    match v with 
      | var_0 _ _ => 0 
      | var_S _ _ _ v => S (var_to_nat v)
    end. 
  
  Definition var_eqb l t t' (v : var l t) (v' : var l t') :=
    NPeano.Nat.eqb (var_to_nat v) (var_to_nat v').  
  
End var. 

Arguments var {T} _ _. 
Arguments var_0 {T} {E} {t}. 
Arguments var_S {T} {E} {t} {t'} _. 
Arguments var_lift {T E F t} v. 
Arguments var_eqb {T l t t'} _ _. 

Fixpoint var_map {A B: Type} (F : A -> B) (l : list A) t (v : var l t) : var (List.map F l) (F t) :=
  match v with
    | var_0 E t => var_0 
    | var_S E t t' x => var_S (var_map F E _ x)
  end. 


Module Tuple. 
  Section t. 
    Variable T : Type. 
    Variable F : T -> Type. 

    Fixpoint of_list l : Type :=
      match l with 
          nil => unit
        | cons t q => (F t * of_list q)%type
      end. 
    
    Fixpoint app l1 l2 : of_list l1 -> of_list l2 -> of_list (List.app l1 l2) :=
      match l1 with 
        | nil => fun _ (x : of_list l2) => x 
        | cons t q => fun (X : F t * of_list q) Y => 
                       let (A,B) := X in (A, app q l2 B Y)
      end. 
    
    Fixpoint get l t (v: var l t): of_list l -> F t :=
      match v with 
        | var_0  _ _ => fun e => (fst e)
        | var_S _ _ _ v => fun e => get _ _ v (snd e)
      end. 
    
    Fixpoint set l t (v : var l t) : F t ->  of_list l -> of_list l:=
      match v  with 
        | var_0 _ _ => fun x e => (x, snd e)
        | var_S _ _ _ v => fun x e => (fst e, set _ _ v x (snd e))
      end. 

  Fixpoint init (el : forall t, F t) l : of_list l :=
    match l with 
      | nil => tt
      | cons t q => (el t, init el q)
    end. 
  End t. 

  Section map. 
    Context {T : Type} {F F': T -> Type}.
    Variable (up : forall a,  F a -> F' a ).
    Fixpoint map l : of_list T F l -> of_list T F' l :=
      match l with 
        | nil => fun x => x
        | cons t q => fun xs =>
                       let (x,xs) := xs in 
                         (up t x, map q xs)
      end. 
  End map. 

  Section map2. 
    Context {T : Type} {F : T -> Type} {F' : T -> Type}. 
    Variable (up : forall a,  F a -> F' a -> F' a). 
    Definition map2 l : of_list T F l -> of_list T F' l -> of_list T F' l. 
    induction l. simpl. auto. 
    simpl. intros [x xs] [y ys]. split. apply up; auto.  
    apply IHl; auto. 
    Defined. 
  End map2. 

  Section map3. 
    Context {T : Type} {F F' F'': T -> Type}.
    Variable (up : forall a,  F a -> F' a -> F'' a -> F'' a). 
    Fixpoint map3 l : of_list T F l -> of_list T F' l -> of_list T F'' l -> of_list T F'' l :=
      match l with 
        | nil => fun _ _ x => x
        | cons t q => fun xs ys zs => 
                       let (x,xs) := xs in 
                        let (y,ys) := ys in 
                          let (z,zs) := zs in 
                            (up t x y z, map3 q xs ys zs)
      end. 
  End map3. 

  Section map3o. 
    Context {T : Type} {F F' F'': T -> Type}.
    Variable (up : forall a,  F a -> F' a -> F'' a -> option (F'' a)). 
    Fixpoint map3o l : of_list T F l -> of_list T F' l -> of_list T F'' l -> option (of_list T F'' l) :=
      match l with 
        | nil => fun _ _ x => Some x
        | cons t q => fun xs ys zs => 
                       let (x,xs) := xs in 
                       let (y,ys) := ys in 
                       let (z,zs) := zs in 
                         do t <- up t x y z;
                         do q <- map3o q xs ys zs;
                         Some (t,q) 
      end. 
  End map3o. 
  
  Section fold. 
    Context {T B : Type} {F : T -> Type}. 
    Section inner. 
      Variable l : list T. 
      Variable up : forall a, F a -> var l a -> B -> B.
      
      Fixpoint prefold   s :
        (forall x, var s x -> var l x) -> of_list T F s -> B -> B :=
        match s as s' return  (forall x, var s' x -> var l x) -> of_list T F s' -> B -> B with
          | nil => fun  _ _ acc => acc
          | cons t q => fun f  (X : F t * of_list T F q) acc => 
                     let (x,xs) := X in 
                       let f' := fun x v => f x (var_S v) in
                         (up t x (f t var_0) (prefold q f' xs  acc))
                              
        end.  
      Definition fold   : of_list T F l -> B -> B := (prefold  l (fun x v => v)). 

    (*
    refine (let fold :=
                fix fold l  : ( forall a, F a -> var l a -> B -> B) -> of_list T F l -> B -> B :=
                match l as l' return  ( forall a, F a -> var l' a -> B -> B) -> of_list T F l' -> B -> B with
                    | nil => fun f _ acc => acc
                    | cons t q => fun f  (X : F t * of_list T F q) acc => 
                                   let (x,xs) := X in 
                                   let f' := (fun b (fb : F b) (v : var q b) => f b fb (var_S v)) in
                                     fold q f' xs (f t x var_0 acc)
                end in fold l up).  *)
    End inner. 
    Notation lift f := (fun x v => f x (var_S v)). 
  End fold. 
  Definition fst {T F l} {t: T} : (Tuple.of_list _ F (t::l)%list) -> F t. apply fst. Defined. 
  Definition snd {T F l} {t: T} : (Tuple.of_list _ F (t::l)%list) -> Tuple.of_list _ F l. apply snd. Defined. 

  Inductive pointwise {A} F G (R : forall a, F a -> G a -> Prop): forall (l : list A), Tuple.of_list _ F l -> Tuple.of_list _ G l -> Prop :=
  | pointwise_nil : pointwise F G R List.nil tt tt
  | pointwise_cons : forall t q dt1 dt2 dq1 dq2,
                       R t dt1 dt2 -> 
                       pointwise F G R q dq1 dq2 ->
                       pointwise F G R (t::q) (dt1,dq1) (dt2,dq2). 
  

End Tuple. 

Arguments Tuple.get {T F} l t _ _. 
Arguments Tuple.app {T F} l1 l2 _ _. 
Arguments Tuple.of_list {T} _ _ .  


Module ETuple. 
  Section t. 
    Variable T : Type. 
    Variable F : T -> Type. 

    Fixpoint of_list l : Type :=
      match l with 
        |  nil => unit
        | cons t q =>
            match q with 
                | nil => F t
                | cons t' q' => (F t * of_list q)%type
            end
      end. 
    

    Definition fst {t l} : of_list (t :: l) -> F t. 
    intros X. simpl in X. destruct l.  auto. destruct X. auto. 
    Defined. 
    
    Definition snd {t l} : of_list (t :: l) -> of_list l. 
    intros X. simpl in X. destruct l.  auto.  apply tt. destruct X. auto. 
    Defined. 
    
    Definition pair {t l} : F t -> of_list l -> of_list (t::l). 
    intros. simpl. destruct l. auto. auto. 
    Defined. 
    
    Definition app l1 l2 : of_list l1 -> of_list l2 -> of_list (List.app l1 l2). 
    refine (let fix app l1 l2 : of_list l1 -> of_list l2 -> of_list (List.app l1 l2) :=
                match l1 with 
                  | nil => fun _ e => e
                  | cons t q => fun X Y => 
                                let A := fst X in 
                                let B := snd X in 
                                  pair A (app _ _ B Y)
                end in app l1 l2).
    Defined. 
    
    Fixpoint get l t (v: var l t): of_list l -> F t :=
      match v with 
        | var_0  _ _ => fun e => (fst e)
        | var_S _ _ _ v => fun e => get _ _ v (snd e)
      end. 
    
    Fixpoint set l t (v : var l t) : F t ->  of_list l -> of_list l:=
      match v  with 
        | var_0 _ _ => fun x e => pair x (snd e)
        | var_S _ _ _ v => fun x e => pair (fst e) (set _ _ v x (snd e))
      end. 
    
    Definition init (el : forall t, F t) l : of_list l. 
    induction l. simpl. apply tt. 
    destruct l. simpl. auto. simpl. 
    split; auto. 
    Defined. 
  End t. 
  
  Section map2. 
    Context {T : Type} {F : T -> Type} {F' : T -> Type}. 
    Variable (up : forall a,  F a -> F' a -> F' a). 
    Definition map2 l : of_list T F l -> of_list T F' l -> of_list T F' l. 
    induction l. simpl. auto. 
    simpl. destruct l. apply up. intros [x xs] [y ys]. split; auto. 
    Defined. 
  End map2. 
End ETuple. 

Arguments ETuple.get {T F} l t _ _. 
Arguments ETuple.app {T F} l1 l2 _ _. 
Arguments ETuple.of_list {T} _ _ .  


Module Abstract. 
  Record T :=
    {
      carrier :> Type;
      eqb : carrier -> carrier -> bool;
      lt  : carrier -> carrier -> bool
    }. 
End Abstract. 

Module Finite. 
  Record T ( n : nat) :Type := mk
    {
      val : nat;
      range : val < n
    }. 
  Arguments val {n} _. 

  Definition eqb {n} (x y : T n) :=
    NPeano.Nat.eqb (val x) (val y). 

  Definition ltb {n} (x y : T n) :=
    NPeano.Nat.ltb (val x) (val y). 
  Require NPeano. 
  Definition repr {n} (v : nat) : T (S n). 
  refine (mk (S n)  (NPeano.modulo v (S n)) _).
  abstract (apply NPeano.Nat.mod_upper_bound; discriminate). 
  Defined.
 
  Definition next {n} (x : T (S n)) :  T (S n) :=
    repr (S (val x)).  
                                
End Finite. 
Require Array. 
Module Regfile := Array. 

(*

(* Notation "<: val 'as' 'int' n :>" := (Word.mk n val _).  *)

Fixpoint lt_nat_bool n m : bool :=
  match n,m with 
    | 0, S _ => true
    | S n, S m => lt_nat_bool n m 
    | _, _ => false
  end. 


Module FIFO. 
  Section t. 
    Definition T (n : nat) X:= list X. 

    Context {X : Type}. 
    Definition push {n} x (q : T n X) : T n X:=           
      List.app q (cons x nil). 
        
    Definition first {n} (q : T n X) : option X := 
      match  q with 
        | nil => None
        | cons t q => Some t
      end. 
    
    Definition pop {n} (q : T n X) := 
      match q with 
          | nil => None
          | cons t q => Some q
      end.

    Definition isempty {n} (q : T n X) :=
      match q with 
          | nil => true
          | _ => false
      end. 

    Definition isfull {n} (q : T n X) := 
      negb (lt_nat_bool (List.length q) n). 
    
    Definition clear {n} (q : T n X) : T n X:= nil. 
  End t. 
End FIFO. 

*)
 

Definition relation A := A -> A -> Prop. 
Definition union {A} (R S : relation A) := fun x y => R x y \/ S x y. 

Delimit Scope dlist_scope with dlist. 

Module DList. 
  Section t. 
  
  Variable X : Type. 
  Variable P : X -> Type. 
  Inductive T  : list X -> Type := 
      | nil : T nil
      | cons : forall (t : X) q, P t -> T q -> T (cons t q).  
  
  Fixpoint Forall (Q: forall (x : X), P x -> Prop) l (dl : T l) :=
    match dl with 
        | nil => True
        | cons t q dt dq => Q t dt /\ Forall Q q dq
    end. 
  
  Fixpoint init (el : forall t, P t) l : T l :=
    match l with 
      | List.nil => nil
      | List.cons t q => cons _ _ (el t) (init el q)
    end. 



  (** * Head and tail *)
  Arguments cons t q _ _%dlist. 
  Arguments T _%list. 
  Definition hd t q (x : T (t::q)): P t :=
    match x as y in T l return
       (match l return (T l -> Type) with 
         | [] => fun _ : T [] => ID
         | a::b => fun _ : T (a :: b) => P a
        end%list y)
    with 
      | nil => @id
      | cons _ _ t q => t
    end.

  Definition tl t q (x : T (t::q)): T q :=
    match x as y in T l return
       (match l return (T l -> Type) with 
         | [] => fun _ : T [] => ID
         | a::b => fun _ : T (a :: b) => T b
        end%list y)
    with 
      | nil => @id
      | cons _ _ t q => q
    end.

  Fixpoint get l t (v: var l t): T l -> P t :=
    match v with 
      | var_0  _ _ => fun e => hd _ _ e
      | var_S _ _ _ v => fun e => get _ _ v  (tl _ _ e)
      end. 

  Fixpoint set l t (v : var l t) : P t ->  T l -> T l:=
    match v  with 
        | var_0 _ _ => fun x e => cons _ _  x (tl _ _ e)
        | var_S _ _ _ v => fun x e => cons _ _  (hd _ _ e) (set _ _ v x (tl _ _ e))
    end. 

  (** * Concatenation of T (append)  *)
  Definition app : forall (l1 l2 : list X), 
                         T l1 -> T l2 -> T (List.app l1 l2).   
  refine (
      (fix app (l1 l2 : list X) {struct l1} :
       T l1 -> T l2 -> T (l1 ++ l2) :=
       match l1 as l3 return (T l3 -> T l2 -> T (l3 ++ l2)) with
         | [] => fun (_ : T []) (dl2 : T l2) => dl2
         | (t :: q)%list =>
             fun (dl1 : T (t :: q)) (dl2 : T l2) =>
               cons t (q ++ l2)%list (hd t q dl1)
                          (app q l2 (tl t q dl1) dl2)
      end%list)). 
  Defined. 
  

  (** * Other functions operating on tuples like things *)
  Variable E : X -> Type.
  
  Section foldo. 
    Variable F : forall (t : X), P t -> E t -> option (E t). 
    Fixpoint fold (l : list X) (d : T l) : Tuple.of_list E l -> option (Tuple.of_list E l):=
      match d with
          nil => fun v => Some v
        | cons t q pt dlq => fun v =>
            do x <- F t pt (fst v);
            do y <- fold q dlq (snd v);
            Some (x,y)
      end.
  End foldo. 

  Section s2. 

    Variable F : forall (t : X), P t -> E t. 

    Definition fold' (l : list X) (dl : T l) : Tuple.of_list E l. 
    induction dl. simpl. apply tt. 
    simpl. destruct q. auto. split. auto. auto. 
    Defined. 
  End s2. 

End t. 

Arguments T {X} P _%list. 
Arguments nil {X P}. 
Arguments cons {X P} {t q} _ _%dlist.  
(* Arguments fold' {X P E} _ _ _.  *)
Arguments app {X P l1 l2} _%dlist _%dlist. 
Arguments get {X P l t} _ _%dlist.  
Arguments set {X P l t} _ _ _%dlist.  

Arguments Forall {X P} _ {l}%list _%dlist. 
Arguments init {X P} _ l%list.
Section ops. 
  Variable X : Type. 
  Variable (F G : X -> Type). 
  Variable (Op : forall x, F x -> G x). 
  Definition to_tuple (l : list X) : T F l -> Tuple.of_list G l. 
  refine ((fix F l (hl : T F l) : Tuple.of_list G l :=
           match hl in T _ l return Tuple.of_list G l with 
                                  | nil => tt
                                  | cons t q T Q =>  ((Op t T),(F q Q))
           end) l).
  Defined. 

  Definition to_etuple (l : list X) : T F l -> ETuple.of_list G l. 
  refine ((fix F l (hl : T F l) : ETuple.of_list G l :=
           match hl in T _ l return ETuple.of_list G l with 
                                  | nil => tt
                                  | cons t q T Q =>  ETuple.pair X G (Op t T) (F q Q)
           end) l).
  Defined. 
  
  Definition map ( l : list X) : T F l -> T G l. 
  refine ((fix F l (hl : T F l) : T G l := 
          match hl in T _ l return T G l with 
            | nil => nil
            | cons t q T Q => cons (Op _ T) (F _ Q)
          end) l). 
  Defined. 
End ops. 
Arguments to_tuple {X F G} Op {_} _%dlist. 
Arguments to_etuple {X F G} Op {_} _%dlist. 
Arguments map {X F G} Op {_} _%dlist. 

Lemma map_to_tuple_commute {X} (F G H : X -> Type)
                            (Op : forall x, F x -> G x) (Op' : forall x : X, G x -> H x)
                            (l : list X) (dl : T F l) :
  to_tuple Op' (map Op dl) = 
  to_tuple (fun x dx => Op' x (Op x dx)) dl. 
Proof.
  induction dl. reflexivity.
  simpl. f_equal. apply IHdl. 
Qed. 


Lemma map_to_etuple_commute {X} (F G H : X -> Type)
                            (Op : forall x, F x -> G x) (Op' : forall x : X, G x -> H x)
                            (l : list X) (dl : T F l) :
  to_etuple Op' (map Op dl) = 
  to_etuple (fun x dx => Op' x (Op x dx)) dl. 
Proof.
  induction dl. reflexivity.
  simpl. f_equal. apply IHdl. 
Qed. 
  
Definition hmap :
  forall (X Y : Type) (P : Y -> Type) (Q : X -> Type)
    (F :  X -> Y), 
    (forall x : X, P (F x) -> Q x) -> forall l : list X, T P (List.map F l) -> T Q l. 
induction l. simpl. constructor. 
simpl. intros. inversion X1.   subst. constructor. auto. auto. 
Defined. 

Definition dmap {A B} (F : A -> Type) (G: B -> Type) (C : A -> B) (D : forall x, F x -> G ( C x)) (l: list  A) (dl : T F l) : T G (List.map C l). 
  induction dl. simpl. constructor. 
  simpl. constructor. apply D.  auto. 
  apply IHdl. 
Defined. 

Inductive pointwise {A} F G (R : forall a, F a -> G a -> Prop): forall (l : list A), T F l -> T G l -> Prop :=
| pointwise_nil : pointwise F G R List.nil nil nil
| pointwise_cons : forall t q dt1 dt2 dq1 dq2,
                     R t dt1 dt2 -> 
                     pointwise F G R q dq1 dq2 ->
                     pointwise F G R (t::q) (cons dt1 dq1) (cons dt2 dq2). 
Arguments hd {X P t q} _%dlist.  
Arguments tl {X P t q} _%dlist.  
Section map3. 
  Context {X : Type} {F F' F'': X -> Type}.
  Variable (up : forall a,  F a -> F' a -> F'' a -> F'' a). 
  Fixpoint map3 l : T F l -> T F' l -> T F'' l -> T F'' l :=
    match l with 
      | List.nil => fun _ _ x => x
      | List.cons t q => fun xs ys zs => 
                         let (x,xs) := (hd xs, tl xs) in 
                         let (y,ys) := (hd ys, tl ys) in 
                         let (z,zs) := (hd zs, tl zs) in 
                           cons (up t x y z)  (map3 q xs ys zs)
    end. 
End map3. 

Section map3o. 
  Context {X : Type} {F F' F'': X -> Type}.
  Variable (up : forall a,  F a -> F' a -> F'' a -> option (F'' a)). 
  Fixpoint map3o l :  T F l ->  T F' l ->  T F'' l -> option (T F'' l) :=
    match l with 
        | List.nil => fun _ _ x => Some x
        | List.cons t q => fun xs ys zs => 
                         let (x,xs) := (hd xs, tl xs) in 
                         let (y,ys) := (hd ys, tl ys) in 
                         let (z,zs) := (hd zs, tl zs) in 
                           do t <- up t x y z;
                           do q <- map3o q xs ys zs;
                           Some (cons t q) 
    end. 
End map3o. 

Require Import Equality.

Lemma inversion_dlist_cons {A F} : forall (t : A) q (dl : DList.T F (t :: q)), 
                              exists hd tl, dl = (cons hd tl)%dlist. 
Proof. 
  intros.  dependent destruction dl. eauto. 
Qed. 

Lemma inversion_dlist_nil {A} {F : A -> Type}  (dl : DList.T F []) :
                              dl = (nil)%dlist. 
Proof. 
  dependent destruction dl. reflexivity. 
Qed. 

Require Import Equality.
Lemma inversion_pointwise {A F G} P (t : A) q dt dq dt' dq':
  pointwise F G P (t :: q)%list (cons dt dq) (cons dt'  dq') ->
  pointwise F G P q dq dq' /\ P t dt dt'. 
Proof. 
  intros H.  
  inversion H;
    repeat match goal with 
               H : existT _ _ _ = existT _ _ _ |- _ => apply Eqdep.EqdepTheory.inj_pair2 in H
           end; subst; auto. 
Qed. 

Ltac inversion :=
  match goal with 
    | H : DList.T _ (_ :: _) |- _ => 
        destruct (inversion_dlist_cons _ _ H) as [? [? ?]]
    | H : DList.T _ ([]) |- _ => 
        pose proof (inversion_dlist_nil H)
  end; subst. 


End DList. 

Notation "[ ]" := DList.nil : dlist_scope.
Notation "t :: q" := (DList.cons t q) : dlist_scope.
Notation "[ a ; .. ; b ]" := (a :: .. (b :: []) ..)%dlist : dlist_scope.

Arguments DList.pointwise {A F G} _ l%list _%dlist _%dlist. 

