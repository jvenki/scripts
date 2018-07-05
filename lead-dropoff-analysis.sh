while getopts ":d:s:o:" opt; do
    case $opt in
        s) src_dir="$OPTARG"
        ;;
        d) for_date="$OPTARG"
        ;;
        o) out_dir="$OPTARG"
        ;;
    esac
done

declare -a in_dir="${out_dir}/${for_date}/in"
declare -a out_dir="${out_dir}/${for_date}/out"
declare -a files_to_be_parsed=("LoanDukaan.log" "localhost_access.log" "clickstream.log")
declare -a experiment_id="ex338";
declare -a treatments=("t1" "t2" "t3");

function initialize() {
    if [ ! -d "$in_dir" ]; then
        mkdir -p "$in_dir"
        for cntr_dir in $src_dir/B*; do
            container_name=$(basename ${cntr_dir})
            for fn in ${files_to_be_parsed[@]}; do
                cp ${src_dir}/${container_name}/DAS/tomcat/logs/${fn}.${for_date}.gz ${in_dir}/${fn}.${for_date}.${container_name}.gz
                gunzip ${in_dir}/${fn}.${for_date}.${container_name}.gz
            done
        done
    fi

    if [ ! -d "$out_dir" ]; then
        mkdir -p "$out_dir"
    fi
}

function parse_session_ids_which_got_CC_SL() {
    echo "Searching for the SL SMS access patterns in clickstream.log files..."
    grep "credit-card-smart-landing.*smsCampaign=true" $in_dir/clickstream.log.* \
        | awk '{
            split($0, tokens, ""); 
            ip_address = tokens[2];
            session_id = tokens[4];
            user_agent = tokens[9];
            user_agent_family = "Unknown";
            if (match(user_agent, /Android.*Version\/[.0-9]*.*Mobile Safari\/[.0-9]*/)) {
                user_agent_family = "Android Webview";
            } else if (match(user_agent, /Android.*Chrome\/[.0-9]* Mobile/)) {
                user_agent_family = "Chrome (Android Mobile)";;
            } else if (match(user_agent, /Android.*Chrome\/[.0-9]*/) && !(user_agent ~ "Mobile") ) {
                user_agent_family = "Chrome (Android Tablet)";;
            } else if (match(user_agent, /Windows NT.*Chrome\/[.0-9]*/)) {
                user_agent_family = "Chrome (Windows Desktop)";;
            } else if (match(user_agent, /Macintosh; Intel Mac OS X .* AppleWebKit\/[.0-9]* .* Chrome\/[.0-9]* Safari\/[.0-9]*/)) {
                user_agent_family = "Chrome (Mac)";;
            } else if (match(user_agent, /Linux x86_64.*Chrome\/[.0-9]*/)) {
                user_agent_family = "Chrome (Linux)";;
            } else if (match(user_agent, /\(iPhone; CPU iPhone OS .*\) AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Mobile\/[A-Z0-9a-z]* Safari\/[.0-9]*/)) {    
                user_agent_family = "Safari (iPhone)"
            } else if (match(user_agent, /\(Macintosh.*\) AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Safari\/[.0-9]*/)) {    
                user_agent_family = "Safari (Mac)"
            } else if (match(user_agent, /Mozilla\/5.0 \(X11; Ubuntu; Linux i686; rv:24.0\) Gecko\/20100101 Firefox\/24.0/)) {
                user_agent_family = "Firefox (Blacklisted)";
            } else if (match(user_agent, /\(Android [.0-9]*; Mobile; rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]*/)) {
                user_agent_family = "Firefox (Android Mobile)";
            } else if (match(user_agent, /\(Mobile; .*Android; rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]* KAIOS\/[.0-9]*/)) {
                user_agent_family = "Firefox (KAIOS)";
            } else if (match(user_agent, /\(Windows NT [.0-9]*; .*rv:[.0-9a-z]*\) Gecko\/[.0-9]* Firefox\/[.0-9]*/)) {
                user_agent_family = "Firefox (Windows Desktop)";
            } else if (match(user_agent, /Android.*AppleWebKit\/[.0-9]* .* Mobile Safari\/[.0-9]*/) || match(user_agent, /Android.*AppleWebKit\/[.0-9]* .* Version\/[.0-9]* Safari\/[.0-9]*/)) {
                user_agent_family = "Android Browser";
            } else if (match(user_agent, /^Opera.*/)) {
                user_agent_family = "Opera";
            } else if (match(user_agent, /MSIE .* Trident/)) {
                user_agent_family = "Internet Explorer";
            } else if (match(user_agent, /UCBrowser\/[.0-9]* U3\/[.0-9]* Mobile Safari\/[.0-9]*/) || match(user_agent, /^UCWEB\/2.0.*UCBrowser\/[.0-9]*/)) {
                user_agent_family = "UCBrowser";
            } else if (match(user_agent, /SamsungBrowser\/[.0-9]* Mobile Safari\/[.0-9]*/)) {
                user_agent_family = "SamsungBrowser";
            } else if (match(user_agent, /OppoBrowser/)) {
                user_agent_family = "OppoBrowser";
            } else if (match(user_agent, /^okhttp\/[.0-9]*$/)) {
                user_agent_family = "BB-App";
            } else if (match(user_agent, /^Dalvik.*/)) {
                user_agent_family = "Dalvik";
            } else if (match(user_agent, /^Apache-HttpClient\/UNAVAILABLE.*/)) {
                user_agent_family = "ApacheHTTPClient";
            } else if (match(user_agent, /^Mozilla\/5.0 \(BB10; Touch\)/) || match(user_agent, /^Mozilla\/5.0 \(BB10; Kbd\)/)) {
                user_agent_family = "BlackBerry";
            } else if (match(user_agent, /^facebookexternalhit\/1.1/)) {
                user_agent_family = "Facebook Crawler";
            } else if (match(user_agent, /SimpleScraper/)) {
                user_agent_family = "SimpleScraper";
            }
            print ip_address "\t" session_id "\t" user_agent "\t" user_agent_family
        }' \
        > $out_dir/tmp_clickstream_sl_alone.txt

    echo "Computing the SessionIDs which opened CC SL SMSCampaign..."
    awk '{print $2}' $out_dir/tmp_clickstream_sl_alone.txt | sort | uniq > "$out_dir"/session_ids_including_blacklisted.txt
    grep -v "Firefox (Blacklisted)" $out_dir/tmp_clickstream_sl_alone.txt | awk '{print $2}' | sort | uniq > "$out_dir"/session_ids.txt
}

function categorize_sessions_based_on_treatments() {
    echo "Categorizing the sessions/localhost_acccess as various Treatments..."
    rm "$out_dir"/localhost_access-*.txt "$out_dir"/session_ids-t*.txt

    cd $out_dir
    split -l 3000 -d --additional-suffix .txt session_ids.txt tmp_session_ids-part-
    cd -

    for treatment in "${treatments[@]}"; do
        touch $out_dir/session_ids-"$treatment".txt
    done

    for part in "$out_dir"/tmp_session_ids-part-*.txt; do
        echo "    Processing " $part
        ./agrep -f $part $in_dir/LoanDukaan.log.* \
            | grep "The CAMPAIGN_KEY session attribute modified to .*${experiment_id}t*" \
            | sed -e "s/The CAMPAIGN_KEY session attribute modified to //g" \
            | awk '{print $3 " " $8}' \
            | sort | uniq -c | awk '{print $2 "\t" $3 "\t" $1}' \
            > "$out_dir"/tmp_session_ids_categorization.txt

        awk -v experiment_id="$experiment_id" -v treatments="${treatments[*]}" -v out_dir="$out_dir" -v in_dir="$in_dir" -F\| '{
            split(treatments, treatments_array, " ")
            for (i in treatments_array) {
                treatment=treatments_array[i];
                pattern=experiment_id""treatment; 
                if ($1 ~ pattern) { 
                    split($1, tokens, "\t"); 
                    print tokens[1] >> out_dir"/session_ids-"treatment".txt";
                    localhost_access_grep_cmd = "grep " tokens[1] " " in_dir"/localhost_access.log.* >> " out_dir"/localhost_access-" treatment ".txt";
                    system(localhost_access_grep_cmd);
                }
            }
        }' "$out_dir"/tmp_session_ids_categorization.txt
    done

    for treatment in "${treatments[@]}"; do
        sort "$out_dir"/session_ids-"$treatment".txt -o "$out_dir"/session_ids-"$treatment".txt
    done

    rm "$out_dir"/tmp_session_ids-part-*.txt "$out_dir"/tmp_session_ids_categorization.txt
}

function compute_session_activity() {
    echo "Computing the Session Activity..."
    rm "$out_dir"/session_activity-*.txt

    for treatment in "${treatments[@]}"; do
        echo "    Processing treatment $treatment" 
        while IFS='' read -r session_id || [[ -n "$line" ]]; do
            grep "$session_id" "$out_dir"/localhost_access-"$treatment".txt \
                | grep -Ev "GET /personal-loan|POST /personal-loan|GET /car-loan|POST /car-loan|GET /used-car-loan| POST /used-car-loan|GET /home-loan|POST /home-loan|GET /debit-card|POST /debit-card|GET /savings-account|POST /savings-account" \
                | grep -Ev "POST /saveLead.html|GET /credit-score|GET /.*credit-report|GET /no-credit-report.html|GET /creditReportFromToken.html|POST /credit_tracker|GET /ct-.*|POST /ct-.*|POST /.*credit-report.*|GET /credit-report-status.html|GET /websocket/creditTracker" \
                | grep -Ev "GET / HTTP/1.1|GET /struts/domTT.js|GET /saveGeoLocation.html|GET /myaccount.html|GET /verifyWorkEmail.html|GET /gzip_|POST /sendCode.html|POST /verifyCode.html|GET /.*getHeaderAjax.html|GET /getAppsFlyerLinkParams.html|GET .*/queried-options.html|GET .*/autoComplete.html|POST .*/recommend.html|GET /recommended-options.html|GET /myaccount_ajax.html|POST /ajax-login-status.html|GET /getNativeLoginWidget.html|POST /signin_iframe.html|GET /privacy-policy.html|POST /signup_iframe.html|POST /short_signup_iframe_json.html|GET /getLatestMobileNumber.html|POST /forgotpwd_iframe.html|GET /recent-searches.html|GET /help-centre.html" \
                | grep -Ev "POST /credit-card/create_app_event_for_geolocator.html|POST /credit-card/sendCode.html|GET /credit-card/mobilePixel.html|POST /credit-card/verifyCode.html|GET /checkMatch.html|POST /credit-card/sendPANNotification.html|GET /credit-card/congratulations.html|GET /setEventDetails.html|GET /signin_social.html|GET /.*/preLoadImages.html|GET /credit-card/get-dynamic-offers.html|GET /credit-card/subscribeToNewsLetterMC.html|GET /credit-card/verifyOwnershipForm.html|GET /credit-card/.*-credit-card.html|GET /credit-card/load-elig-slides.html|POST /credit-card/offer-details-compare.html|POST /credit-card/document_types.html|POST /credit-card/clear_and_load_next_form.html|POST /credit-card/load_next_form_app.html|POST /credit-card/file_upload.html|GET /credit-card/credit-card/fetchShortlistedOffers.html|POST /credit-card/getCityState.html|GET /credit-card/application_view.html|POST /credit-card/verifyOwnership.html|GET /credit-card/application_scrape.html|POST /credit-card/remove_file.html|POST /credit-card/triggerAutoSubmit.html|POST /credit-card/checkApprovalStatus.html|POST /credit-card/application_dpCheck.html|POST /credit-card/load-prefill-data.html|POST /credit-card/ajax-offer-details-mobile.html" \
                | sed 's/.*GET \/credit-card.html.*/LP/g; s/.*GET \/credit-card-smart-landing.html.*/SL_LANDING/g; s/.*GET \/.*credit-card.html?variant=slide.*/REG_SLIDE/g;' \
                | sed 's/.*\/credit-card\/search-offers.html.*/SEARCH_OFFERS/g; s/.*GET \/credit-card\/search.html.*/SEARCH/g; s/.*POST \/credit-card\/post-eligibility-details.html.*/POST_ELIG/g; s/.*GET \/credit-card\/zero-offers.html.*/ZERO_OFFERS/g; s/.*GET \/credit-card\/get-more-offers.html.*/MORE_OFFERS/g; s/.*GET \/credit-card\/newCompleteEligibility.html.*/COMPLETE_ELIG/g; s/.*GET \/credit-card\/showBaseMPAjaxElig.html.*/SHOW_BASE_ELIG/g; s/.*POST \/credit-card\/eligibility-submit.html.*/ELIG_SUBMIT/g; ' \
                | sed 's/.*GET \/credit-card\/offers-with-searchId.html.*/OFFERS_WITH_SEARCH_ID/g; s/.*POST \/credit-card\/preapproved_offers_available.html.*/PAPQ/g; s/.*GET \/credit-card\/offer-details.html.*/OFFER_DETAILS/g; s/.*GET \/credit-card\/card-details.html.*/CARD_DETAILS/g; s/.*GET \/credit-card\/application_create.html.*/APP_CREATE/g; s/.*GET \/credit-card\/application_edit.html.*/APP_EDIT/g; s/.*POST \/credit-card\/application_save.html.*/APP_SAVE/g; s/.*\/credit-card\/application_submit.html.*/APP_SUBMIT/g; s/.*GET \/credit-card\/dpReRunOffers.html.*/DP_CHECK/g; ' \
                | sed 's/.*POST \/credit-card\/create-lead-before-search.html.*/CREATE_LEAD_BEFORE_SEARCH/g; ' \
                | sed 's/.*POST \/ajax-content.html.*/INIT_SESSION/g; s/.*POST \/.*\/ajax-content.html.*/INIT_SESSION2/g;' \
                | cut -d, -f2- | paste -sd, \
                | sed "s/^/$session_id /" \
                >> "$out_dir"/session_activity-"$treatment".txt
        done < "$out_dir"/session_ids-"$treatment".txt
    done
}

function print_summary() {
    echo "Summary of SL accesses"
    echo "Number of Unique Sessions = " `cat ${out_dir}/session_ids-t1.txt ${out_dir}/session_ids-t2.txt ${out_dir}/session_ids-t3.txt | wc -l`
    echo "  Number of Sessions which enjoyed T1 & T2 & T3 =" `awk '{print $1" "$2}' "$out_dir"/session_ids-t1.txt  "$out_dir"/session_ids-t2.txt "$out_dir"/session_ids-t3.txt | sort | uniq -c | awk '{if ($1==3){print $2" "$3}}' | wc -l`
    echo "  Number of Sessions which enjoyed T1 & T2 =" `comm -12 "$out_dir"/session_ids-t1.txt "$out_dir"/session_ids-t2.txt  | wc -l`
    echo "  Number of Sessions which enjoyed T2 & T3 =" `comm -12 "$out_dir"/session_ids-t2.txt "$out_dir"/session_ids-t3.txt  | wc -l`
    echo "  Number of Sessions which enjoyed T1 & T3 =" `comm -12 "$out_dir"/session_ids-t1.txt "$out_dir"/session_ids-t3.txt  | wc -l`

    echo ""
    printf "%10s %15s %15s %20s %5s %20s %20s\n" "Treatment" "Sessions#" "SLAccess#" "SlideshowRendered#" "%" "DirectToSearch#" "WrongZeroOffersInT3"
    for treatment in "${treatments[@]}"; do
        number_of_unique_sessions=$(cat "$out_dir"/session_ids-"$treatment".txt | wc -l)
        number_of_sl_accesses=$(grep "credit-card-smart-landing.*" out/localhost_access-$treatment.txt | wc -l)
        number_of_slideshow_renders=$(grep "credit-card-smart-landing.* 200 " out/localhost_access-$treatment.txt | wc -l)
        number_of_direct_to_search=$(grep "credit-card-smart-landing.* 302 " out/localhost_access-$treatment.txt | wc -l)
        wrong_zero_offers_in_t3=0

        if [ $treatment = "t3" ]; then
            number_of_slideshow_renders=$(grep "SL_LANDING.*CREATE_LEAD_BEFORE_SEARCH" out/session_activity-t3.txt | wc -l)
            number_of_direct_to_search=$(grep "SL_LANDING" out/session_activity-t3.txt  | grep -v "CREATE_LEAD_BEFORE_SEARCH" | wc -l)
            wrong_zero_offers_in_t3=$(grep "SL_LANDING,POST_ELIG,SEARCH,ZERO_OFFERS" out/session_activity-t3.txt | wc -l)
        fi
        perc_of_renders=$(echo "scale=2 ; $number_of_slideshow_renders / ($number_of_slideshow_renders+$number_of_direct_to_search) * 100" | bc)

        printf "%10s %15s %15s %20s %5s %20s %20s\n" $treatment $number_of_unique_sessions $number_of_sl_accesses $number_of_slideshow_renders $perc_of_renders $number_of_direct_to_search $wrong_zero_offers_in_t3
    done
}

initialize

# parse_session_ids_which_got_CC_SL
categorize_sessions_based_on_treatments
compute_session_activity
#print_summary
