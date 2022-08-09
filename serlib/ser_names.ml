(************************************************************************)
(*         *   The Coq Proof Assistant / The Coq Development Team       *)
(*  v      *   INRIA, CNRS and contributors - Copyright 1999-2018       *)
(* <O___,, *       (see CREDITS file for the list of authors)           *)
(*   \VV/  **************************************************************)
(*    //   *    This file is distributed under the terms of the         *)
(*         *     GNU Lesser General Public License Version 2.1          *)
(*         *     (see LICENSE file for the text of the license)         *)
(************************************************************************)

(************************************************************************)
(* Coq serialization API/Plugin                                         *)
(* Copyright 2016-2018 MINES ParisTech -- Dual License LGPL 2.1 / GPL3+ *)
(* Written by: Emilio J. Gallego Arias                                  *)
(************************************************************************)
(* Status: Very Experimental                                            *)
(************************************************************************)

open Sexplib.Std
open Ppx_python_runtime
open Ppx_hash_lib.Std.Hash.Builtin
open Ppx_compare_lib.Builtin

open Names

module Int  = Ser_int
module CAst = Ser_cAst

(************************************************************************)
(* Serialization of Names.mli                                           *)
(************************************************************************)

module Id = struct

  (* Id.t: private *)
  module Id_ = struct
    type t = Names.Id.t
    type _t = Id of string [@@deriving sexp,yojson,python,hash,compare]
    let of_t id = Id (Id.to_string id)
    let to_t (Id id) = Id.of_string_soft id
  end

  module Self = SerType.Biject(Id_)
  include Self

  module Set = Ser_cSet.Make(Names.Id.Set)(Self)
  module Map = Ser_cMap.Make(Names.Id.Map)(Self)

end

module Name = struct

(* Name.t: public *)
type t =
  [%import: Names.Name.t]
  [@@deriving sexp,yojson,python,hash,compare]

end

module DirPath = struct

  (* DirPath.t: private *)
  module DirPath_ = struct
    type t = Names.DirPath.t
    type _t = DirPath of Id.t list
    [@@deriving sexp,yojson,python,hash,compare]

    let of_t dp = DirPath (DirPath.repr dp)
    let to_t (DirPath dpl) = DirPath.make dpl
  end

  include SerType.Biject(DirPath_)

end

module DPmap = Ser_cMap.Make(DPmap)(DirPath)

module Label = struct

  (* Label.t: private *)
  module Label_= struct
    type t = [%import: Names.Label.t]

    (* XXX: This will miss the tag *)
    type _t = Id.t
    [@@deriving sexp,yojson,python,hash,compare]

    let to_t = Label.of_id
    let of_t = Label.to_id
  end

  include SerType.Biject(Label_)
end

module MBId = struct

  (* MBId.t: private *)
  module MBIdBij = struct
    type t = [%import: Names.MBId.t]

    type _t = Mbid of int * Id.t * DirPath.t
    [@@deriving sexp,yojson,python,hash,compare]

  end

include SerType.Pierce(MBIdBij)

end

module ModPath = struct

(* ModPath.t: public *)
type t = [%import: Names.ModPath.t]
         [@@deriving sexp,yojson,python,hash,compare]
end

module MPmap = Ser_cMap.Make(MPmap)(ModPath)

(* KerName: private *)
module KerName = struct

  module KerBij = struct
    type t = Names.KerName.t
    type _t = KerName of ModPath.t * Label.t
    [@@deriving sexp,yojson,python,hash,compare]

    let of_t kn = let mp, l = KerName.repr kn in KerName (mp,l)
    let to_t (KerName (mp,l)) = KerName.make mp l
  end

  let equal = KerName.equal
  include SerType.Biject(KerBij)

end

module Constant = struct

  module ConBij = struct
    (* Constant.t: private *)
    type t = Names.Constant.t
    type _t = Constant of KerName.t * KerName.t option
    [@@deriving sexp,yojson,python,hash,compare]

    let of_t cs =
      let cu, cc = Constant.(user cs, canonical cs) in
      if KerName.equal cu cc then Constant (cu, None) else Constant (cu, Some cc)
    let to_t = function
      | Constant (cu, None) -> Constant.make1 cu
      | Constant (cu, Some cc) -> Constant.make cu cc
  end

  include SerType.Biject(ConBij)

end

module Cset_env = Ser_cSet.Make(Cset_env)(Constant)

module Cmap = Ser_cMap.Make(Cmap)(Constant)
module Cmap_env = Ser_cMap.Make(Cmap_env)(Constant)

module MutInd = struct

(* MutInd.t: private *)
  module BijectSpec = struct
    type t = [%import: Names.MutInd.t]
    type _t = MutInd of KerName.t * KerName.t option
    [@@deriving sexp,yojson,python,hash,compare]

    let of_t cs =
      let cu, cc = MutInd.(user cs, canonical cs) in
      if KerName.equal cu cc then MutInd (cu, None) else MutInd (cu, Some cc)

    let to_t = function
      | MutInd (cu, None) -> MutInd.make1 cu
      | MutInd (cu, Some cc) -> MutInd.make cu cc
  end

  include SerType.Biject(BijectSpec)
end

module Mindmap = Ser_cMap.Make(Mindmap)(MutInd)
module Mindmap_env = Ser_cMap.Make(Mindmap_env)(MutInd)

type 'a tableKey =
  [%import: 'a Names.tableKey]
  [@@deriving sexp]

type variable =
  [%import: Names.variable]
  [@@deriving sexp,yojson,python,hash,compare]

(* Inductive and constructor = public *)
module Ind = struct
  type t =
  [%import: Names.Ind.t]
  [@@deriving sexp,yojson,python,hash,compare]
end

module Indset_env = Ser_cSet.Make(Indset_env)(Ind)

type inductive =
  [%import: Names.inductive]
  [@@deriving sexp,yojson,python,hash,compare]

module Construct = struct
  type t =
  [%import: Names.Construct.t]
  [@@deriving sexp,yojson,python,hash,compare]

end
type constructor =
  [%import: Names.constructor]
  [@@deriving sexp,yojson,python,hash,compare]

(* Projection: private *)
module Projection = struct

  module Repr = struct
    module PierceSpec = struct
      type t = Names.Projection.Repr.t
      type _t =
        { proj_ind : inductive
        ; proj_relevant : bool
        ; proj_npars : int
        ; proj_arg : int
        ; proj_name : Label.t
        } [@@deriving sexp,yojson,python,hash,compare]
    end
    include SerType.Pierce(PierceSpec)
  end

  module PierceSpec = struct
    type t = [%import: Names.Projection.t]
    type _t = Repr.t * bool
    [@@deriving sexp,yojson,python,hash,compare]
  end
  include SerType.Pierce(PierceSpec)
end

module GlobRef = struct
  type t = [%import: Names.GlobRef.t]
  [@@deriving sexp,yojson,python,hash,compare]
end

type lident =
  [%import: Names.lident]
  [@@deriving sexp,yojson,python,hash,compare]

type lname =
  [%import: Names.lname]
  [@@deriving sexp,yojson,python,hash,compare]

type lstring =
  [%import: Names.lstring]
  [@@deriving sexp,yojson,python,hash,compare]
