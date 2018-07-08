while getopts ":d:s:o:f" opt; do
    case $opt in
        s) src_dir="$OPTARG"
        ;;
        d) for_date="$OPTARG"
        ;;
        o) out_dir="$OPTARG"
        ;;
        f) force_init=true
        ;;
    esac
done

declare in_dir="${out_dir}/${for_date}/in"
declare out_dir="${out_dir}/${for_date}/out"
declare experiment_id="ex338";
declare -a files_to_be_parsed=("LoanDukaan.log" "localhost_access.log" "clickstream.log")
declare -a treatments=("t1" "t2" "t3");

declare blacklisted_ua="Mozilla\/5.0 \(X11; Ubuntu; Linux i686; rv:24.0\) Gecko\/20100101 Firefox\/24.0|okhttp\/[.0-9]*"
declare ignore_url_patterns='GET /personal-loan|POST /personal-loan|GET /car-loan|POST /car-loan|GET /used-car-loan|POST /used-car-loan|GET /home-loan|POST /home-loan|GET /debit-card|POST /debit-card|GET /savings-account|POST /savings-account|POST /saveLead.html|GET /credit-score|GET /.*credit-report|GET /no-credit-report.html|GET /creditReportFromToken.html|POST /credit_tracker|GET /ct-.*|POST /ct-.*|POST /.*credit-report.*|GET /credit-report-status.html|GET /websocket/creditTracker|GET / HTTP/1.1|GET /struts/domTT.js|GET /saveGeoLocation.html|GET /myaccount.html|GET /verifyWorkEmail.html|GET /gzip_|POST /sendCode.html|POST /verifyCode.html|GET /.*getHeaderAjax.html|GET /getAppsFlyerLinkParams.html|GET .*/queried-options.html|GET .*/autoComplete.html|POST .*/recommend.html|GET /recommended-options.html|GET /myaccount_ajax.html|POST /ajax-login-status.html|GET /getNativeLoginWidget.html|POST /signin_iframe.html|GET /privacy-policy.html|POST /signup_iframe.html|POST /short_signup_iframe_json.html|GET /getLatestMobileNumber.html|POST /forgotpwd_iframe.html|GET /recent-searches.html|GET /help-centre.html|POST /credit-card/create_app_event_for_geolocator.html|POST /credit-card/sendCode.html|GET /credit-card/mobilePixel.html|POST /credit-card/verifyCode.html|GET /checkMatch.html|POST /credit-card/sendPANNotification.html|GET /credit-card/congratulations.html|GET /setEventDetails.html|GET /signin_social.html|GET /.*/preLoadImages.html|GET /credit-card/get-dynamic-offers.html|GET /credit-card/subscribeToNewsLetterMC.html|GET /credit-card/verifyOwnershipForm.html|GET /credit-card/.*-credit-card.html|GET /credit-card/load-elig-slides.html|POST /credit-card/offer-details-compare.html|POST /credit-card/document_types.html|POST /credit-card/clear_and_load_next_form.html|POST /credit-card/load_next_form_app.html|POST /credit-card/file_upload.html|GET /credit-card/credit-card/fetchShortlistedOffers.html|POST /credit-card/getCityState.html|GET /credit-card/application_view.html|POST /credit-card/verifyOwnership.html|GET /credit-card/application_scrape.html|POST /credit-card/remove_file.html|POST /credit-card/triggerAutoSubmit.html|POST /credit-card/checkApprovalStatus.html|POST /credit-card/application_dpCheck.html|POST /credit-card/load-prefill-data.html|POST /credit-card/ajax-offer-details-mobile.html'
declare replace_url_patterns='
s/"GET \/credit-card.html.*"/LP/g; 
s/"GET \/credit-card-smart-landing.html.*"/SL_LANDING/g; 
s/"GET \/.*credit-card.html?variant=slide.*"/REG_SLIDE/g; 
s/"GET \/credit-card\/search-offers.html.*"/SEARCH_OFFERS_G/g; 
s/"POST \/credit-card\/search-offers.html.*"/SEARCH_OFFERS_P/g; 
s/"GET \/credit-card\/search.html.*"/SEARCH/g; 
s/"POST \/credit-card\/post-eligibility-details.html.*"/POST_ELIG/g; 
s/"GET \/credit-card\/zero-offers.html.*"/ZERO_OFFERS/g; 
s/"GET \/credit-card\/get-more-offers.html.*"/MORE_OFFERS/g; 
s/"GET \/credit-card\/newCompleteEligibility.html.*"/COMPLETE_ELIG/g; 
s/"GET \/credit-card\/showBaseMPAjaxElig.html.*"/SHOW_BASE_ELIG/g; 
s/"POST \/credit-card\/eligibility-submit.html.*"/ELIG_SUBMIT/g; 
s/"GET \/credit-card\/offers-with-searchId.html.*"/OFFERS_WITH_SEARCH_ID/g; 
s/"POST \/credit-card\/preapproved_offers_available.html.*"/PAPQ/g; 
s/"GET \/credit-card\/offer-details.html.*"/OFFER_DETAILS/g; 
s/"GET \/credit-card\/card-details.html.*"/CARD_DETAILS/g; 
s/"GET \/credit-card\/application_create.html.*"/APP_CREATE/g; 
s/"GET \/credit-card\/application_edit.html.*"/APP_EDIT/g; 
s/"POST \/credit-card\/application_save.html.*"/APP_SAVE/g; 
s/"POST \/credit-card\/application_submit.html.*"/APP_SUBMIT/g; 
s/"GET \/credit-card\/dpReRunOffers.html.*"/DP_CHECK/g; 
s/"POST \/credit-card\/create-lead-before-search.html.*"/CREATE_LEAD_BEFORE_SEARCH/g; 
s/"POST \/ajax-content.html.*"/INIT_SESSION/g; 
s/"POST \/.*\/ajax-content.html.*"/INIT_SESSION2/g; 
'

declare user_agent_family_awk_fn='function compute_ua_family(user_agent) {
    if (match(user_agent, /Android.*Version\/[.0-9]*.*Mobile Safari\/[.0-9]*/)) {
        return "AndroidWebview";
    } else if (match(user_agent, /Android.*Chrome\/[.0-9]* Mobile/)) {
        return "ChromeAndroidMobile";
    } else if (match(user_agent, /Android.*Chrome\/[.0-9]*/) && !(user_agent ~ "Mobile") ) {
        return "ChromeAndroidTablet";
    } else if (match(user_agent, /Windows NT.*Chrome\/[.0-9]*/)) {
        return "ChromeWindowsDesktop";
    } else if (match(user_agent, /Macintosh; Intel Mac OS X .* AppleWebKit\/[.0-9]* .* Chrome\/[.0-9]* Safari\/[.0-9]*/)) {
        return "ChromeMac";
    } else if (match(user_agent, /Linux x86_64.*Chrome\/[.0-9]*/)) {
        return "ChromeLinux";
    } else if (match(user_agent, /\(iPhone; CPU iPhone OS .*\) AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Mobile\/[A-Z0-9a-z]* Safari\/[.0-9]*/)) {    
        return "SafariiPhone";
    } else if (match(user_agent, /\(Macintosh.*\) AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Safari\/[.0-9]*/)) {    
        return "SafariMac";
    } else if (match(user_agent, /Mozilla\/5.0 \(X11; Ubuntu; Linux i686; rv:24.0\) Gecko\/20100101 Firefox\/24.0/)) {
        return "FirefoxBlacklisted";
    } else if (match(user_agent, /\(Android [.0-9]*; Mobile; rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]*/)) {
        return "FirefoxAndroidMobile";
    } else if (match(user_agent, /\(Mobile; .*Android; rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]* KAIOS\/[.0-9]*/)) {
        return "FirefoxKAIOS";
    } else if (match(user_agent, /\(Windows NT [.0-9]*; .*rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]*/)) {
        return "FirefoxWindowsDesktop";
    } else if (match(user_agent, /Android.*AppleWebKit\/[.0-9]* .* Mobile Safari\/[.0-9]*/) || match(user_agent, /Android.*AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Safari\/[.0-9]*/)) {
        return "AndroidBrowser";
    } else if (match(user_agent, /^Opera.*/)) {
        return "Opera";
    } else if (match(user_agent, /MSIE .* Trident/)) {
        return "InternetExplorer";
    } else if (match(user_agent, /UCBrowser\/[.0-9]* U3\/[.0-9]* Mobile Safari\/[.0-9]*/) || match(user_agent, /^UCWEB\/2.0.*UCBrowser\/[.0-9]*/)) {
        return "UCBrowser";
    } else if (match(user_agent, /SamsungBrowser\/[.0-9]* Mobile Safari\/[.0-9]*/)) {
        return "SamsungBrowser";
    } else if (match(user_agent, /OppoBrowser/)) {
        return "OppoBrowser";
    } else if (match(user_agent, /^okhttp\/[.0-9]*$/)) {
        return "OkHttp";
    } else if (match(user_agent, /^Dalvik.*/)) {
        return "Dalvik";
    } else if (match(user_agent, /^Apache-HttpClient\/UNAVAILABLE.*/)) {
        return "ApacheHTTPClient";
    } else if (match(user_agent, /^Mozilla\/5.0 \(BB10; Touch\)/) || match(user_agent, /^Mozilla\/5.0 \(BB10; Kbd\)/)) {
        return "BlackBerry";
    } else if (match(user_agent, /^facebookexternalhit\/1.1/)) {
        return "FacebookCrawler";
    } else if (match(user_agent, /SimpleScraper/)) {
        return "SimpleScraper";
    }
}
'

function center_print() {
    padding="$(head -c $((($2-${#1}-2)/2)) < /dev/zero | tr '\0' ' ')"
    printf '#%s%s%s#\n' "$padding" "$1" "$padding" 
}

function print_title() {
    local title=$1
    local color_none='\033[0m'
    local color_cyan='\033[1;36m';
    printf "\n${color_cyan}${title}${color_none}\n";
    printf "${color_cyan}%s${color_none}\n" $(head -c $((${#title})) < /dev/zero | tr '\0' '-');
}

function print_progress() {
    local completed_ops_count="$1"
    local total_ops_count="$2"
    local msg="$3"
    local skipped=$4

    if [ -e $skipped ]; then
        skipped=false
    fi

    local color_none='\033[0m'
    local color_cyan='\033[1;36m';
    local color_yellow='\033[1;33m'
    local color_green='\033[1;32m'

    if [ $skipped == true ]; then
        printf "%-50s: ${color_cyan}SKIPPED${color_none}\n" "$msg";
    else
        perc_completed=$((completed_ops_count*100/total_ops_count))
        if [ $perc_completed == 100 ]; then
            printf "%-50s: Completed: ${color_green}% -51s(%s%%)${color_none}\r" "$msg" $(head -c $((perc_completed/2)) < /dev/zero | tr '\0' '#') $perc_completed;
        else
            printf "%-50s: Completed: ${color_yellow}% -51s(%s%%)${color_none}\r" "$msg" $(head -c $((perc_completed/2)) < /dev/zero | tr '\0' '#') $perc_completed;
        fi
    fi
}

function initialize() {
    if [ "$force_init" == true ]; then
        echo "Force Reset is set. Deleting pre-generated artifacts"
        rm -rf "${out_dir}/${for_date}"
    fi

    local op_name="Creating $in_dir"
    if [ ! -d "$in_dir" ]; then
        print_progress 1 1 "$op_name"
        printf "\n"
        mkdir -p "$in_dir"

        local op_name="    Copying relevant files"
        number_of_containers=$(ls $src_dir | grep B.* | wc -l)
        total_ops_count=$((${#files_to_be_parsed[@]}*2*number_of_containers))
        i=0
        print_progress $i $total_ops_count "$op_name" 
        for cntr_dir in $src_dir/B*; do
            container_name=$(basename ${cntr_dir})
            for fn in ${files_to_be_parsed[@]}; do
                if [ -f ${src_dir}/${container_name}/DAS/tomcat/logs/${fn}.${for_date}.gz ]; then
                    cp ${src_dir}/${container_name}/DAS/tomcat/logs/${fn}.${for_date}.gz ${in_dir}/${fn}.${for_date}.${container_name}.gz
                    print_progress $((++i)) $total_ops_count "$op_name" 
                    gunzip ${in_dir}/${fn}.${for_date}.${container_name}.gz
                    print_progress $((++i)) $total_ops_count "$op_name" 
                else
                    i=$((i+2))
                    print_progress $i $total_ops_count "$op_name" 
                fi
            done
        done
        printf "\n"
    else
        print_progress 1 1 "$op_name" true
    fi

    local op_name="Creating $out_dir"
    if [ ! -d "$out_dir" ]; then
        print_progress 1 1 "$op_name"
        mkdir -p "$out_dir"
        printf "\n"
    else
        print_progress 1 1 "$op_name" true
    fi
}

function parse_session_ids_which_got_CC_SL() {
    local campaign_type=$1
    local op_name="Computing SessionIDs which opened CC-SL '$campaign_type'";
    if [ -f $out_dir/"$campaign_type"_session_id_to_ua.txt ]; then
        print_progress 1 1 "$op_name" true 
        return
    fi

    echo "$op_name"
    grep "credit-card-smart-landing.*${campaign_type}Campaign=true" $in_dir/clickstream.log.* \
        | grep -vE "$blacklisted_ua" \
        | awk -F : "$user_agent_family_awk_fn"'{
            split($0, tokens, ""); 
            ip_address = tokens[2];
            session_id = tokens[4];
            user_agent = tokens[9];
            user_agent_family =  compute_ua_family(user_agent);
            print session_id "\t" ip_address "\t" user_agent_family "\t" "\""user_agent"\""
        }' \
        > $out_dir/tmp_clickstream_sl_alone.txt

    sort $out_dir/tmp_clickstream_sl_alone.txt | uniq > "$out_dir"/"$campaign_type"_session_id_to_ua.txt
    rm $out_dir/tmp_clickstream_sl_alone.txt
}

function categorize_sessions_based_on_treatments() {
    local campaign_type=$1
    local op_name="Categorizing '$campaign_type' Sessions by Treatments"

    if [ -f "$out_dir"/"$campaign_type"_session_ids-t1.txt ]; then
        print_progress 1 1 "$op_name" true
        return
    fi

    awk '{print $1}' "$out_dir"/"$campaign_type"_session_id_to_ua.txt > "$out_dir"/tmp_session_ids_only.txt

    number_of_chunks=$(split --verbose -l 3000 -d --additional-suffix .txt $out_dir/tmp_session_ids_only.txt tmp_session_ids-chunk- | wc -l)
    total_ops_count=$((number_of_chunks+1+${#treatments[@]}))
    mv tmp_session_ids-chunk-* $out_dir/.

    i=0
    print_progress $i $total_ops_count "$op_name" 
    for chunk in "$out_dir"/tmp_session_ids-chunk-*.txt; do
        ./agrep -f $chunk $in_dir/LoanDukaan.log.* \
            | grep "The CAMPAIGN_KEY session attribute modified to .*${experiment_id}t*" \
            | sed -e "s/The CAMPAIGN_KEY session attribute modified to //g;" \
            | awk -v experiment_id="$experiment_id" '{gsub(".*"experiment_id, "", $8); print $3 " " $8}' \
            | sort | uniq | awk '{print $1 "\t" $2}' \
            >> "$out_dir"/tmp_session_ids_categorization_1.txt

        print_progress $((++i)) $total_ops_count "$op_name" 
    done

    join $out_dir/"$campaign_type"_session_id_to_ua.txt $out_dir/tmp_session_ids_categorization_1.txt > $out_dir/tmp_session_ids_categorization_2.txt
    print_progress $((++i)) $total_ops_count "$op_name" 
    for treatment in "${treatments[@]}"; do
        grep ".*${treatment}$" $out_dir/tmp_session_ids_categorization_2.txt | sort > "$out_dir"/"$campaign_type"_session_ids-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$op_name" 
    done

    printf "\n"
    rm "$out_dir"/tmp_session_ids-chunk-*.txt "$out_dir"/tmp_session_ids_categorization* $out_dir/tmp_session_ids_only.txt
}

function compute_session_activity() {
    local campaign_type=$1
    local op_name="Computing the Session Activity"

    if [ -f "$out_dir"/"$campaign_type"_session_activity-t1.txt ]; then
        print_progress 1 1 "$op_name" true
        return
    fi

    i=0
    total_ops_count=$((${#treatments[@]}*3))
    print_progress $i $total_ops_count "$op_name" 
    for treatment in "${treatments[@]}"; do
        awk '{print $1}' "$out_dir"/"$campaign_type"_session_ids-"$treatment".txt > "$out_dir"/tmp_session_ids_only-"$treatment".txt

        ./agrep -f "$out_dir"/tmp_session_ids_only-"$treatment".txt $in_dir/clickstream.log.* \
            | awk -F : "$user_agent_family_awk_fn"'{
                split($0, tokens, ""); 
                ip_address = tokens[2];
                session_id = tokens[4];
                request_url = tokens[6] "?" tokens[7];
                originating_url = tokens[8];
                user_agent = tokens[9];
                user_agent_family =  compute_ua_family(user_agent);
                gsub("&origin_path.*$", "", request_url);
                print session_id "\t" ip_address "\t" user_agent_family "\t" "\""user_agent"\"" "\t" request_url "\t" originating_url
            }' \
            > "$out_dir"/"$campaign_type"_clickstream-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$op_name" 

        ./agrep -f "$out_dir"/tmp_session_ids_only-"$treatment".txt $in_dir/localhost_access.log.* > "$out_dir"/"$campaign_type"_localhost_access-"$treatment".txt
        cat -n "$out_dir"/"$campaign_type"_localhost_access-"$treatment".txt \
            | awk 'BEGIN{ OFS="\t" }{print $13, $1, $6"]", $8 " " $9 " " $10, $11}' \
            | sort -k1,1 -k2,2n \
            | awk 'BEGIN{ FS=OFS="\t" }{print $1, $3, $4, $5}' \
            > "$out_dir"/tmp_localhost_access-"$treatment".txt
        join -1 1 -2 1 -t $'\t' $out_dir/"$campaign_type"_session_id_to_ua.txt "$out_dir"/tmp_localhost_access-"$treatment".txt > "$out_dir"/"$campaign_type"_localhost_access-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$op_name" 

        grep -Ev "$ignore_url_patterns" "$out_dir"/"$campaign_type"_localhost_access-"$treatment".txt | sed "$replace_url_patterns" \
            | awk 'BEGIN{ FS=OFS="\t" }{
                if (NR == 0) {
                    last_session_id = ""
                    aggr_activity = ""
                    last_session_info = ""
                }
                curr_session_id = $1;
                if (last_session_id == "" || curr_session_id == last_session_id) {
                    aggr_activity = aggr_activity $6 ",";
                } else if (last_session_id != "" && curr_session_id != last_session_id) {
                    print last_session_info, aggr_activity;
                    aggr_activity = $6 ",";
                }
                last_session_id = curr_session_id;
                last_session_info = $1 "\t" $2 "\t" $3 "\t" $4 "\t"
            } END {print last_session_info, aggr_activity}' \
            >> "$out_dir"/"$campaign_type"_session_activity-"$treatment".txt
        print_progress $((++i)) $total_ops_count "$op_name"

        rm "$out_dir"/tmp_localhost_access-"$treatment".txt "$out_dir"/tmp_session_ids_only-"$treatment".txt
    done
    printf "\n"
}

function analyze_requests_wo_ajaxcontent() {
    local campaign_type=$1
    local op_name="Analyzing UserAgents"

    if [ -f "$out_dir"/"$campaign_type"_ua_analysis_proper_wo_ajax_content.txt ]; then
        print_progress 1 1 "$op_name" true
        return
    fi
    echo $op_name

    grep -P "okhttp" "$out_dir"/"$campaign_type"_session_activity-t*.txt \
        | awk '{print $2}' \
        | grep -f - "$out_dir"/"$campaign_type"_localhost_access-t*.txt \
        | grep -v okhttp \
        | awk 'BEGIN {FS="\t"}{print $4}' \
        | sed -r 's/.*\(.*Android [.0-9]*; //g; s/\).*//g; s/en-[a-zA-Z]{2}; //g; s/; wv//g' \
        | sort | uniq \
        > "$out_dir"/"$campaign_type"_ua_analysis_emitting_devices.txt
    echo "    Devices which requested with UserAgent okhttp has been written to " "$out_dir"/"$campaign_type"_ua_analysis_emitting_devices.txt

    grep "SL_LANDING,$" "$out_dir"/"$campaign_type"_session_activity-*.txt \
        | grep -v okhttp \
        | awk 'BEGIN{OFS=FS="\t"}{print $3,$4}' \
        | sort  | uniq \
        > "$out_dir"/"$campaign_type"_ua_analysis_proper_wo_ajax_content.txt
    echo "    Proper UserAgents (not okhttp) for which we didnt see ajax-content call are exported to " "$out_dir"/"$campaign_type"_ua_analysis_proper_wo_ajax_content.html
}

function print_summary() {
    local campaign_type=$1
    echo "Number of Unique Sessions = " `cat ${out_dir}/"$campaign_type"_session_ids-t1.txt ${out_dir}/"$campaign_type"_session_ids-t2.txt ${out_dir}/"$campaign_type"_session_ids-t3.txt | wc -l`
    printf "%10s %15s %15s %20s %5s %20s\n" "Treatment" "Sessions#" "SLAccess#" "SlideshowRendered#" "%" "DirectToSearch#"
    for treatment in "${treatments[@]}"; do
        sl_campaign_url="GET \/credit-card-smart-landing.*${campaign_type}Campaign=true"
        number_of_unique_sessions=$(cat "$out_dir"/"$campaign_type"_session_ids-"$treatment".txt | wc -l)
        number_of_sl_accesses=$(grep "$sl_campaign_url" "$out_dir"/"$campaign_type"_localhost_access-$treatment.txt | wc -l)
        number_of_slideshow_renders=$(grep "$sl_campaign_url.*200$" "$out_dir"/"$campaign_type"_localhost_access-$treatment.txt | wc -l)
        number_of_direct_to_search=$(grep "$sl_campaign_url.*302$" "$out_dir"/"$campaign_type"_localhost_access-$treatment.txt | wc -l)

        if [ $treatment = "t3" ]; then
            number_of_slideshow_renders=$(grep -Eo "SL_LANDING(,INIT_SESSION2)?,CREATE_LEAD_BEFORE_SEARCH" "$out_dir"/"$campaign_type"_session_activity-t3.txt | wc -l)
            number_of_direct_to_search=$(grep -Eo "SL_LANDING(,INIT_SESSION2)?(,POST_ELIG)?,SEARCH" "$out_dir"/"$campaign_type"_session_activity-t3.txt | wc -l)
        fi
        perc_of_renders=$((number_of_slideshow_renders*100/(number_of_slideshow_renders+number_of_direct_to_search)))

        printf "%10s %15s %15s %20s %5s %20s\n" $treatment $number_of_unique_sessions $number_of_sl_accesses $number_of_slideshow_renders $perc_of_renders $number_of_direct_to_search
    done

    echo "Number of times SEARCH has been called from SL URL for AndroidWebview = " `grep "AndroidWebview.*GET \/credit-card\/search.html.*smartLanding=true.*newSlideshow=true" "$out_dir"/"$campaign_type"_localhost_access-t3.txt | awk 'BEGIN{FS="\t"}{print $6}' | wc -l`    
}

function main() {
    local col_width=120

    local start_time=$(($(date +%s%N)/1000000))
    printf "\e[8;50;${col_width}t"
    clear
    initialize
    for campaign_type in "sms" "email"; do
        print_title "ANALYSING LOGS FOR '$campaign_type' SESSIONS"
        parse_session_ids_which_got_CC_SL "$campaign_type"
        categorize_sessions_based_on_treatments "$campaign_type"
        compute_session_activity "$campaign_type"
        analyze_requests_wo_ajaxcontent "$campaign_type"
        print_summary "$campaign_type"
    done
    local end_time=$(($(date +%s%N)/1000000))
    printf "\nTotal Time Taken = %dms\n" $((end_time-start_time))
}

main
