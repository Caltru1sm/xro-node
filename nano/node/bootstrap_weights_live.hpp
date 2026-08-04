#pragma once

#include <string>
#include <vector>
namespace nano::weights
{
// Bootstrap weights for live network
//
// XRO (RaiblocksOne) representative weight snapshot, taken from the live ledger
// at block height 625096 on 2026-08-04 via the `representatives` RPC. Includes
// every representative holding >= 1e36 raw.
//
// Upstream shipped this list EMPTY with max_blocks_live set to the Nano mainnet
// height. Because XRO's ledger never reaches that height, the node stays
// permanently in bootstrap-weight mode (ledger::weight() consults this map before
// the ledger) while the map itself holds nothing. A node with a complete ledger is
// unaffected - weight() falls through to real ledger weights on a miss - but a
// bootstrapping node has no ledger weights yet, leaving it with zero trust anchors
// and unable to establish quorum.
std::vector<std::pair<std::string, std::string>> preconfigured_weights_live = {
	{ "xro_17xnzfitcg476uezh5ttso54f3i674hynr88jynoyonoi3i6a5ncrh6xd9tj", "67825965623289714082159091900686466290" },
	{ "xro_3qn4pwex9bx3jy34jg6ogxxngwq3fmb13trs78weybwbe9fg5msgehj9qrcn", "26782664070853974341530471449877232229" },
	{ "xro_3z4u1upq8e798pj669tki5osyit6jmyzwn6cba56pnsp77hna8ze9gku93np", "23414170137612928046211523701525037300" },
	{ "xro_31m77pcy8wpyfm7z749z76y3n8tgj94b4gtbpdnwtwxmeikh1rjwpfuzb3a3", "17893646141595730310130670677064177108" },
	{ "xro_3x684hpm4qqxszgzt1b6gb4spqcupeof5db4bnai35msra3db3c1o5fyc5y5", "17862060331097339214558567353992208274" },
	{ "xro_1nanswapnscbjjr6nd8bjbyp7o3gby1r8m18rbmge3mj8y5bihh71sura9dx", "17849920024504709276957487461058819292" },
	{ "xro_1mnkyfrnzq1tkspbyc3kztcg31tkif3ets4ktwsbp6567z4c11u3b94jez9z", "8850222280814487342454300000000000000" },
	{ "xro_3nodeysrn7kse1izijdh5nnepqfpe4iwcdafe8juqmywbs6qq3pt66ccbn9w", "8848124593694000000000000863897861120" },
	{ "xro_33i6jgorw5csxw6p1f98fpzpkjdkmg61aakcqpsbepe8tpdk7w767n7zm53t", "7953373730030000000000000000000000000" },
	{ "xro_1m1nzthjrr975sjy5yzteqikecu16bgmsikdschskjzhht98761e7qu15eae", "7953355504167339214558567316746788754" },
	{ "xro_3fishntjrycmdnhxxf8stcxfo7jks4ba1hqf8tt9bq51kech65hrq8ttng4e", "7259883059559000005420000000000000000" },
	{ "xro_1txsbyfk645bjjuiooig9m1egrjiw4mzuwp77io3b95k1mdnp868rui6w3b1", "5892590131413010598810197268579571712" },
	{ "xro_1rfb48bj9tr6a95whcruebi458359afktmzqfoa687q1i5om7gthstpfyf3c", "5215059015519142579447458096803886080" },
	{ "xro_3k7it8smgm7zmgn9ruuorbj7f4qbd9j43ktff5xzff1giapubxxp5dp9pof4", "2852810799649849581959105600000000000" },
	{ "xro_37jieud5qm66ix9j7iys3z9tuiefrqaqhjbobyqbtsmgmyrzww5jesb8siet", "1893124224740000000000000000000000000" },
	{ "xro_3hmdu7bcy1nbegbheufz1qgrzficifyurzw377mjkgmhqs43tz1rxuqqzr57", "1878364703400000000000000000000000000" },
	{ "xro_3oj94ox7quhwq9pkmrxnhzf3uqmdquw5gr6ijbqoxicc3dugey3gwkr6rp5p", "1873538731399999999999999962754580480" },
	{ "xro_17qh4zzr7ognxuday68j9bkuizp6fyhmiz5wdpdbkgnjgqudpf3p5wxtueyy", "1865760730000000000000000000000000000" },
	{ "xro_13ownqaoojf7oz3796e75nrc9a6fczq1s6ujrne4xnwpjyguqarkb7pdc9qc", "1816428730899999999999999888263741440" },
	{ "xro_1pzu57t1x7fpztowpc78utdu5tr7whja79f5qfr7g64orbqqaoznwfctx6i4", "1811506734270000000000000000000000000" },
	{ "xro_3n3xmudmheob6w7s1a3h4ntrmb7yy37pmyy4rywosy5jrumt68j1fei5thw9", "1806856830299999999999999962754580480" },
	{ "xro_3ndrtnda7i7xnjsprrp6utb8inwwxdfhssbwtyc841bksg74tb77i8kieryg", "1805799994400000000000000000000000000" },
	{ "xro_1p66c3dwjuqwoeijs8etkpxi18hdab54joyxom61ya9g6xpb85nqe86y9yo3", "1805799730299999999999999962754580480" },
	{ "xro_1ozkcxqhit84g69hrb8xiakekqhpe7x1gesu1wnx4ghphzi9hzd6e1p6qgez", "1805252731199999999999999851018321920" },
	{ "xro_3yhro4xfaynh9oqj1m8yyo7zgyzzb9s7mq1kujws36ckpqygjqao4j1pqp5a", "1803744019000000000000000000000000000" },
	{ "xro_3pztmmwbmjz9jsszh3cai37f7qfy9cuq7598nhcg1hfa98ntp4a58sqnadep", "1803743730000000000000000000000000000" },
	{ "xro_3yto11yqd5c4wrhfiqnkjykhseubjoo5f6d99karoiss8ms4bcfok3g77p4i", "1803743730000000000000000000000000000" },
	{ "xro_3hpcjgfzi81pixy4pkr3p4ngyq1sdi3arirfngjgbwno6zj4c19kt18r1q8t", "1496831524688423113537832165406500738" },
};
// Set just above the ledger height at snapshot time, so a syncing node uses the
// anchors above during bootstrap and hands off to real ledger weights once it
// catches up. Upstream's 203134603 is the Nano mainnet height.
uint64_t max_blocks_live = 630000;
}
