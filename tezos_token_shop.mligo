//defining contract types 
type token_supply = { current_stock : nat ; token_address : address ; token_max_price : tez }
type token_shop_storage = (nat, token_supply) map
type return = operation list * token_shop_storage

type token_id = nat
//types needed for a token transfer 
type transfer_destination =
[@layout:comb]
{
  to_ : address;
  token_id : token_id;
  amount : nat;
}
 
type transfer =
[@layout:comb]
{
  from_ : address;
  txs : transfer_destination list;
}

//defining the owner address
let owner_address : address =
  ("tz1bYDxKL9CTJXtQ2Px1Tn3ZmGwNTpQHsnTu" : address)
let donationAddress : address =
  ("tz1Pf1uiDTQXbhD9KCvDkLg7zrJCPrPNBtrQ" : address)

//main function of the token contract
let main (token_kind_index, token_shop_storage : nat * token_shop_storage) : return =
//check if the card exists
  let token_kind : token_supply =
    match Map.find_opt (token_kind_index) token_shop_storage with
    | Some k -> k
    | None -> (failwith "Unknown kind of token" : token_supply)
  in

  let current_purchase_price : tez = token_kind.token_max_price / token_kind.current_stock 
  in
 
  let () = if Tezos.amount >= current_purchase_price then
    failwith "Thank you for the tip!"
  in
 
  let () = if token_kind.current_stock = 0n then
    failwith "Sorry, the token you are trying to purchase is out of stock"
  in
  
 
//update the storage from user transactions
  let token_shop_storage = Map.update
    token_kind_index
    (Some { token_kind with current_stock = abs (token_kind.current_stock - 1n) })
    token_shop_storage
  in
//transfer function operation
  let tr : transfer = {
    from_ = Tezos.self_address;
    txs = [ {
      to_ = Tezos.sender;
      token_id = abs (token_kind.current_stock - 1n);
      amount = 1n;
    } ];
  } 
  in

let entrypoint : transfer list contract = 
    match ( Tezos.get_entrypoint_opt "%transfer" token_kind.token_address : transfer list contract option ) with
    | None -> ( failwith "Invalid external token contract" : transfer list contract )
    | Some e -> e
  in
 
  let fa2_operation : operation =
    Tezos.transaction [tr] 0mutez entrypoint
  in

//payout function to the owner address
let receiver : unit contract =
    match (Tezos.get_contract_opt owner_address : unit contract option) with
    | Some (contract) -> contract
    | None -> (failwith ("Not a contract") : (unit contract))
  in

let donationReceiver : unit contract =
  match (Tezos.get_contract_opt (donationAddress) : unit contract option) with
    Some (contract) -> contract
  | None  -> (failwith ("Not a contract") : (unit contract))
  in

  let donationAmount : tez = Tezos.amount / 10n
  in
 
  let payout_operation : operation = 
    Tezos.transaction unit amount receiver
  in

  let donation_operation : operation = 
    Tezos.transaction unit donationAmount donationReceiver 
  in
//returns the list of operations
  ([fa2_operation ; payout_operation ; donation_operation], token_shop_storage)
