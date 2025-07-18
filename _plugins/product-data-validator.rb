# Verify product data by performing some validation before and after products are enriched.
# Note that the site build is stopped if the validation fails.
#
# The validation done before enrichment is the validation of the properties set by the users.
#
# The validation done after enrichment is mainly the validation of URLs, because most of the URLs
# are generated by the changelogTemplate. Note that this validation is not done by default because
# it takes a lot of time. You can activate it by setting the MUST_CHECK_URLS environment variable to
# true before building the site.

require 'jekyll'
require 'open-uri'
require_relative 'identifier-to-url'

module EndOfLifeHooks
  VERSION = '1.0.0'
  TOPIC = 'Product Validator:'
  VALID_CATEGORIES = %w[app database device framework lang library os server-app service standard]
  VALID_CUSTOM_FIELD_DISPLAY = %w[none api-only after-release-column before-latest-column after-latest-column]

  IGNORED_URL_PREFIXES = {
    'https://www.nokia.com': 'always return a Net::ReadTimeout',
  }
  SUPPRESSED_BECAUSE_402 = 'may trigger a 402 Payment Required'
  SUPPRESSED_BECAUSE_403 = 'may trigger a 403 Forbidden or a redirection forbidden'
  SUPPRESSED_BECAUSE_404 = 'may trigger a 404 Not Found'
  SUPPRESSED_BECAUSE_429 = 'may trigger a 429 Too Many Requests'
  SUPPRESSED_BECAUSE_502 = 'may return a 502 Bad Gateway'
  SUPPRESSED_BECAUSE_503 = 'may return a 503 Service Unavailable'
  SUPPRESSED_BECAUSE_CERT = 'site have an invalid certificate'
  SUPPRESSED_BECAUSE_CONN_FAILED = 'may fail when opening the TCP connection'
  SUPPRESSED_BECAUSE_EOF = 'may return an "unexpected eof while reading" error'
  SUPPRESSED_BECAUSE_TIMEOUT = 'may trigger an open or read timeout'
  SUPPRESSED_BECAUSE_UNAVAILABLE = 'site is temporary unavailable'
  SUPPRESSED_URL_PREFIXES = {
    'https://access.redhat.com/': SUPPRESSED_BECAUSE_403,
    'https://antixlinux.com': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://apex.oracle.com/sod': SUPPRESSED_BECAUSE_403,
    'https://arangodb.com': SUPPRESSED_BECAUSE_403,
    'https://ark.intel.com': SUPPRESSED_BECAUSE_403,
    'https://azure.microsoft.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://business.adobe.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://blogs.oracle.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://blog.system76.com/post/': SUPPRESSED_BECAUSE_404,
    'https://codex.wordpress.org/Supported_Versions': SUPPRESSED_BECAUSE_EOF,
    'https://community.openvpn.net': SUPPRESSED_BECAUSE_403,
    'https://dev.mysql.com': SUPPRESSED_BECAUSE_403,
    'https://docs.arangodb.com': SUPPRESSED_BECAUSE_404,
    'https://docs.clamav.net': SUPPRESSED_BECAUSE_403,
    'https://docs.couchdb.org': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://docs.gitlab.com': SUPPRESSED_BECAUSE_403,
    'https://docs-prv.pcisecuritystandards.org': SUPPRESSED_BECAUSE_403,
    'https://docs.rocket.chat': SUPPRESSED_BECAUSE_403,
    'https://dragonwell-jdk.io/': SUPPRESSED_BECAUSE_UNAVAILABLE,
    'https://docs-cortex.paloaltonetworks.com/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://euro-linux.com': SUPPRESSED_BECAUSE_403,
    'https://ftpdocs.broadcom.com/WebInterface/phpdocs/0/MSPSaccount/COMPAT/AllProdDates.HTML': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://forums.unrealircd.org': SUPPRESSED_BECAUSE_403,
    'https://github.com/angular/angular.js/blob': SUPPRESSED_BECAUSE_502,
    'https://github.com/ansible-community/ansible-build-data/blob/main/4/CHANGELOG-v4.rst': SUPPRESSED_BECAUSE_502,
    'https://github.com/hashicorp/consul/blob/v1.18.2/CHANGELOG.md': SUPPRESSED_BECAUSE_502,
    'https://github.com/hashicorp/consul/blob/v1.19.2/CHANGELOG.md': SUPPRESSED_BECAUSE_502,
    'https://github.com/hashicorp/consul/blob/v1.20.5/CHANGELOG.md': SUPPRESSED_BECAUSE_502,
    'https://github.com/nodejs/node/blob/main/doc/changelogs/': SUPPRESSED_BECAUSE_502,
    'https://github.com': SUPPRESSED_BECAUSE_429,
    'https://helpx.adobe.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.ibm.com/support/pages/node/6451203': SUPPRESSED_BECAUSE_403,
    'https://investors.broadcom.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://jfrog.com/help/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://kernelnewbies.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://make.wordpress.org': SUPPRESSED_BECAUSE_EOF,
    'https://mattermost.com': SUPPRESSED_BECAUSE_403,
    'https://mxlinux.org': SUPPRESSED_BECAUSE_403,
    'https://mirrors.slackware.com': SUPPRESSED_BECAUSE_403,
    'https://moodle.org/': SUPPRESSED_BECAUSE_403,
    'https://opensource.org/licenses/osl-3.0.php': SUPPRESSED_BECAUSE_403,
    'https://oxygenupdater.com/news/all/': SUPPRESSED_BECAUSE_403,
    'https://privatebin.info/': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://reload4j.qos.ch/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://review.lineageos.org/': SUPPRESSED_BECAUSE_502,
    'https://stackoverflow.com': SUPPRESSED_BECAUSE_403,
    'https://support.azul.com': SUPPRESSED_BECAUSE_403,
    'https://support.citrix.com': SUPPRESSED_BECAUSE_403,
    'https://support.fairphone.com': SUPPRESSED_BECAUSE_403,
    'https://support.herodevs.com/hc/en-us/articles/': SUPPRESSED_BECAUSE_403,
    'https://support.microsoft.com': SUPPRESSED_BECAUSE_403,
    'https://twitter.com/OracleAPEX': SUPPRESSED_BECAUSE_403,
    'https://visualstudio.microsoft.com/': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://web.archive.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://webapps.bmc.com': SUPPRESSED_BECAUSE_403,
    'https://wiki.debian.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://wiki.mageia.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://wiki.mozilla.org/Release_Management/Calendar': SUPPRESSED_BECAUSE_403,
    'https://wiki.ubuntu.com': SUPPRESSED_BECAUSE_503,
    'https://wordpress.org': SUPPRESSED_BECAUSE_EOF,
    'https://www.akeneo.com/akeneo-pim-community-edition/': SUPPRESSED_BECAUSE_403,
    'https://www.amazon.com': SUPPRESSED_BECAUSE_403,
    'https://www.atlassian.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.adobe.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.betaarchive.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.citrix.com/products/citrix-virtual-apps-and-desktops/': SUPPRESSED_BECAUSE_403,
    'https://www.clamav.net': SUPPRESSED_BECAUSE_403,
    'https://www.devuan.org': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://www.drupal.org/': SUPPRESSED_BECAUSE_403,
    'https://www.erlang.org/doc/system_principles/misc.html': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://www.intel.com': SUPPRESSED_BECAUSE_403,
    'https://www.java.com/releases/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.mageia.org': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.mail-archive.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.microfocus.com/documentation/visual-cobol/': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.microsoft.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.mulesoft.com': SUPPRESSED_BECAUSE_TIMEOUT,
    'https://www.mysql.com': SUPPRESSED_BECAUSE_403,
    'https://www.netapp.com/data-storage/ontap': SUPPRESSED_BECAUSE_403,
    'https://www.raspberrypi.com': SUPPRESSED_BECAUSE_403,
    'https://www.reddit.com': SUPPRESSED_BECAUSE_403,
    'http://www.slackware.com': SUPPRESSED_BECAUSE_CONN_FAILED,
    'http://www.squid-cache.org/Versions/v6/squid-6.13-RELEASENOTES.html': SUPPRESSED_BECAUSE_CONN_FAILED,
    'https://www.techpowerup.com/gpuz/': SUPPRESSED_BECAUSE_403,
    'https://www.unrealircd.org/docs/UnrealIRCd_releases': SUPPRESSED_BECAUSE_403,
    'https://www.virtualbox.org': SUPPRESSED_BECAUSE_402,
    'https://www.zentyal.com': SUPPRESSED_BECAUSE_403,
  }
  USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0'
  URL_CHECK_OPEN_TIMEOUT = 3
  URL_CHECK_TIMEOUT = 10

  # Global error count
  @@error_count = 0

  def self.increase_error_count
    @@error_count += 1
  end

  def self.error_count
    @@error_count
  end

  def self.validate(product)
    start = Time.now
    Jekyll.logger.debug TOPIC, "Validating '#{product.name}'..."

    error_if = Validator.new('product', product, product.data)
    error_if.is_not_a_string('title')
    error_if.is_not_in('category', EndOfLifeHooks::VALID_CATEGORIES)
    error_if.does_not_match('tags', /^[a-z0-9\-]+( [a-z0-9\-]+)*$/) if product.data.has_key?('tags')
    error_if.does_not_match('permalink', /^\/[a-z0-9-]+$/)
    error_if.does_not_match('alternate_urls', /^\/[a-z0-9\-_]+$/)
    error_if.is_not_a_string('versionCommand') if product.data.has_key?('versionCommand')
    error_if.is_not_an_url('releasePolicyLink') if product.data.has_key?('releasePolicyLink')
    error_if.is_not_an_url('releaseImage') if product.data.has_key?('releaseImage')
    error_if.is_not_an_url('changelogTemplate') if product.data.has_key?('changelogTemplate')
    error_if.is_not_a_string('releaseLabel') if product.data.has_key?('releaseLabel')
    error_if.is_not_a_string('LTSLabel')
    error_if.is_not_a_boolean_nor_a_string('eolColumn')
    error_if.is_not_a_number('eolWarnThreshold')
    error_if.is_not_a_boolean_nor_a_string('eoasColumn')
    error_if.is_not_a_number('eoasWarnThreshold')
    error_if.is_not_a_boolean_nor_a_string('releaseColumn')
    error_if.is_not_a_boolean_nor_a_string('releaseDateColumn')
    error_if.is_not_a_boolean_nor_a_string('discontinuedColumn')
    error_if.is_not_a_number('discontinuedWarnThreshold')
    error_if.is_not_a_boolean_nor_a_string('eoesColumn')
    error_if.is_not_a_number('eoesWarnThreshold')
    error_if.is_not_an_array('identifiers')
    error_if.is_not_an_array('releases')
    error_if.not_ordered_by_release_cycles('releases')
    error_if.undeclared_custom_field('releases')
    error_if.custom_field_type_is_not_string('releases')

    product.data['identifiers'].each { |identifier|
      error_if.is_not_an_identifier('identifiers', identifier)
    }

    if product.data.has_key?('auto')
      error_if = Validator.new('auto', product, product.data['auto'])
      error_if.is_not_an_array('methods')
    end

    product.data['customFields'].each { |column|
      error_if = Validator.new('customFields', product, column)
      error_if.is_not_a_string('name')
      error_if.is_not_in('display', EndOfLifeHooks::VALID_CUSTOM_FIELD_DISPLAY)
      error_if.is_not_a_string('label')
      error_if.is_not_a_string('description') if column.has_key?('description')
      error_if.is_not_an_url('link') if column.has_key?('link')
    }

    release_names = product.data['releases'].map { |release| release['releaseCycle'] }
    release_name_duplicates = release_names.group_by { |name| name }.select { |_, count| count.size > 1 }.keys
    error_if.not_true(release_name_duplicates.length == 0, 'releases', release_name_duplicates, 'Duplicate releases')

    product.data['releases'].each { |release|
      error_if = Validator.new('releases', product, release)
      error_if.does_not_match('releaseCycle', /^[a-z0-9.\-+_]+$/)
      error_if.is_not_a_string('releaseLabel') if release.has_key?('releaseLabel')
      error_if.is_not_a_string('codename') if release.has_key?('codename')
      error_if.is_not_a_date('releaseDate')
      error_if.too_far_in_future('releaseDate')
      error_if.is_not_a_boolean_nor_a_date('eoas') if product.data['eoasColumn']
      error_if.is_not_a_boolean_nor_a_date('eol')
      error_if.is_not_a_boolean_nor_a_date('discontinued') if product.data['discontinuedColumn']
      error_if.is_not_a_boolean_nor_a_date('eoes') if product.data['eoesColumn'] and release.has_key?('eoes')
      error_if.is_not_a_boolean_nor_a_date('lts') if release.has_key?('lts')
      error_if.is_not_a_string('latest') if product.data['releaseColumn']
      error_if.is_not_a_date('latestReleaseDate') if product.data['releaseColumn'] and release.has_key?('latestReleaseDate')
      error_if.too_far_in_future('latestReleaseDate') if product.data['releaseColumn'] and release.has_key?('latestReleaseDate')
      error_if.is_not_an_url('link') if release.has_key?('link') and release['link']

      error_if.is_not_before('releaseDate', 'eoas') if product.data['eoasColumn']
      error_if.is_not_before('releaseDate', 'eol')
      error_if.is_not_before('releaseDate', 'eoes') if product.data['eoesColumn']
      error_if.is_not_before('eoas', 'eol') if product.data['eoasColumn']
      error_if.is_not_before('eoas', 'eoes') if product.data['eoasColumn'] and product.data['eoesColumn']
      error_if.is_not_before('eol', 'eoes') if product.data['eoesColumn']
    }

    Jekyll.logger.debug TOPIC, "Product '#{product.name}' successfully validated in #{(Time.now - start).round(3)} seconds."
  end

  def self.validate_urls(product)
    if ENV.fetch('MUST_CHECK_URLS', false)
      start = Time.now
      Jekyll.logger.info TOPIC, "Validating urls for '#{product.name}'..."

      error_if = Validator.new('product', product, product.data)
      error_if.is_url_invalid('releasePolicyLink') if product.data['releasePolicyLink']
      error_if.is_url_invalid('releaseImage') if product.data['releaseImage']
      error_if.is_url_invalid('iconUrl') if product.data['iconUrl']
      error_if.contains_invalid_urls(product.content)

      product.data['customFields'].each { |field|
        error_if = Validator.new('customFields', product, field)
        error_if.is_url_invalid('link') if field['link']
      }

      product.data['releases'].each { |release|
        error_if = Validator.new('releases', product, release)
        error_if.is_url_invalid('link') if release['link']
      }

      Jekyll.logger.info TOPIC, "Product '#{product.name}' urls successfully validated in #{(Time.now - start).round(3)} seconds."
    end
  end

  private

  class Validator
    def initialize(name, product, data)
      @product = product
      @data = data
      @error_count = 0

      unless data.kind_of?(Hash)
        declare_error(name, data, "expecting an Hash, got #{data.class}")
        @data = {} # prevent further errors
      end
    end

    def error_count
      @error_count
    end

    def not_true(condition, property, value, details)
      unless condition
        declare_error(property, value, details)
      end
    end

    def is_not_an_array(property)
      value = @data[property]
      unless value.kind_of?(Array)
        declare_error(property, value, "expecting an Array, got #{value.class}")
      end
    end

    def is_not_in(property, valid_values)
      value = @data[property]
      unless valid_values.include?(value)
        declare_error(property, value, "expecting one of #{valid_values.join(', ')}")
      end
    end

    def does_not_match(property, regex)
      values = @data[property].kind_of?(Array) ? @data[property] : [@data[property]]
      values.each { |value|
        unless regex.match?(value)
          declare_error(property, value, "should match #{regex}")
        end
      }
    end

    def is_not_a_string(property)
      value = @data[property]
      unless value.kind_of?(String)
        declare_error(property, value, "expecting a value of type String, got #{value.class}")
      end
    end

    def is_not_an_url(property)
      does_not_match(property, /^https?:\/\/.+$/)
    end

    def is_not_a_date(property)
      value = @data[property]
      unless value.respond_to?(:strftime)
        declare_error(property, value, "expecting a value of type boolean or date, got #{value.class}")
      end
    end

    def too_far_in_future(property)
      value = @data[property]
      if value.respond_to?(:strftime) and value > Date.today + 7
        declare_error(property, value, "expecting a value in the next 7 days, got #{value}")
      end
    end

    def is_not_a_number(property)
      value = @data[property]
      unless value.kind_of?(Numeric)
        declare_error(property, value, "expecting a value of type numeric, got #{value.class}")
      end
    end

    def is_not_a_boolean_nor_a_date(property)
      value = @data[property]
      unless [true, false].include?(value) or value.respond_to?(:strftime)
        declare_error(property, value, "expecting a value of type boolean or date, got #{value.class}")
      end
    end

    def is_not_a_boolean_nor_a_string(property)
      value = @data[property]
      unless [true, false].include?(value) or value.kind_of?(String)
        declare_error(property, value, "expecting a value of type boolean or string, got #{value.class}")
      end
    end

    def is_not_before(property1, property2)
      value1 = @data[property1]
      value2 = @data[property2]

      if value1.respond_to?(:strftime) and value2.respond_to?(:strftime) and value1 > value2
        declare_error(property1, value1, "expecting a value before #{property2} (#{value2})")
      end
    end

    # Real validation is delegated to IdentifierToUrl to avoid duplication
    def is_not_an_identifier(property, hash)
      IdentifierToUrl.new.render(hash)
    rescue => e
      declare_error(property, hash, e)
    end

    def not_ordered_by_release_cycles(property)
      releases = @data[property]

      previous_release_cycle = nil
      previous_release_date = nil
      releases.each do |release|
        next if release['outOfOrder']

        release_cycle = release['releaseCycle']
        release_date = release['releaseDate']

        if previous_release_date and previous_release_date < release_date
          declare_error(property, release_cycle, "expecting release (released on #{release_date}) to be before #{previous_release_cycle} (released on #{previous_release_date})")
        end

        previous_release_cycle = release_cycle
        previous_release_date = release_date
      end
    end

    def is_url_invalid(property)
      # strip is necessary because changelogTemplate is sometime reformatted on two lines by latest.py
      url = @data[property].strip
      check_url(url)
    rescue => e
      declare_url_error(property, url, "got an error : '#{e}'")
    end

    # Retrieve all urls in the given markdown-formatted text and check them.
    def contains_invalid_urls(markdown)
      urls = markdown.scan(/]\((?<matching>http[^)"]+)/).flatten # matches [text](url) or [text](url "title")
      urls += markdown.scan(/<(?<matching>http[^>]+)/).flatten # matches <url>
      urls += markdown.scan(/: (?<matching>http[^"\n]+)/).flatten # matches [id]: url or [id]: url "title"
      urls.each do |url|
        begin
          check_url(url.strip) # strip url because matches on [text](url "title") end with a space
        rescue => e
          declare_url_error('content', url, "got an error : '#{e}'")
        end
      end
    end

    def undeclared_custom_field(property)
      releases = @data[property]

      standard_fields = %w[releaseCycle releaseLabel codename releaseDate eoas eol eoes discontinued latest latestReleaseDate link lts outOfOrder]
      custom_fields = @product["customFields"].map { |column| column["name"] }

      releases.each do |release|
        release_cycle = release['releaseCycle']
        release_fields = release.keys

        undeclared_fields = release_fields - standard_fields - custom_fields
        for field in undeclared_fields
          declare_error(field, release_cycle, "undeclared field")
        end
      end
    end

    def custom_field_type_is_not_string(property)
      releases = @data[property]

      custom_fields = @product["customFields"].map { |column| column["name"] }
      releases.each do |release|
        release_cycle = release['releaseCycle']

        for field in custom_fields
          value = release[field]
          # string values may be parsed as Date, but ultimately they are String
          if value != nil and !value.kind_of?(String) and !value.kind_of?(Date)
            declare_error(field, release_cycle, "expecting a value of type String or Date, got #{value.class}")
          end
        end
      end
    end

    def check_url(url)
      ignored_reason = is_ignored(url)
      if ignored_reason
        Jekyll.logger.warn TOPIC, "Ignore URL #{url} : #{ignored_reason}."
        return
      end

      Jekyll.logger.debug TOPIC, "Checking URL #{url}."
      URI.open(url, 'User-Agent' => USER_AGENT, :open_timeout => URL_CHECK_OPEN_TIMEOUT, :read_timeout => URL_CHECK_TIMEOUT) do |response|
        if response.status[0].to_i >= 400
          raise "response code is #{response.status}"
        end
      end
    end

    def is_ignored(url)
      EndOfLifeHooks::IGNORED_URL_PREFIXES.each do |ignored_url, reason|
        return reason if url.start_with?(ignored_url.to_s)
      end

      return nil
    end

    def is_suppressed(url)
      EndOfLifeHooks::SUPPRESSED_URL_PREFIXES.each do |ignored_url, reason|
        return reason if url.start_with?(ignored_url.to_s)
      end

      return nil
    end

    def declare_url_error(property, url, details)
      reason = is_suppressed(url)
      if reason
        Jekyll.logger.warn TOPIC, "Invalid #{property} '#{url}' for #{location}, #{details} (suppressed: #{reason})."
      else
        declare_error(property, url, details)
      end

    end

    def declare_error(property, value, details)
      Jekyll.logger.error TOPIC, "Invalid #{property} '#{value}' for #{location}, #{details}."
      EndOfLifeHooks::increase_error_count()
    end

    def location
      if @data.kind_of?(Hash) and @data.has_key?('releaseCycle')
        "#{@product.name}#releases##{@data['releaseCycle']}"
      elsif @data.kind_of?(Hash) and @data.has_key?('name')
        "#{@product.name}#customField##{@data['name']}"
      else
        @product.name
      end
    end
  end
end

# Must be run before enrichment, hence the high priority.
Jekyll::Hooks.register :pages, :post_init, priority: Jekyll::Hooks::PRIORITY_MAP[:high] do |page, payload|
  if page.data['layout'] == 'product'
    EndOfLifeHooks::validate(page)
  end
end

# Must be run after enrichment, hence the low priority.
Jekyll::Hooks.register :pages, :post_init, priority: Jekyll::Hooks::PRIORITY_MAP[:low] do |page, payload|
  if page.data['layout'] == 'product'
    EndOfLifeHooks::validate_urls(page)
  end
end

# Must be run at the end of all validation
Jekyll::Hooks.register :site, :post_render, priority: Jekyll::Hooks::PRIORITY_MAP[:low] do |site, payload|
  if EndOfLifeHooks::error_count > 0
    raise "Site build canceled : #{EndOfLifeHooks::error_count} errors detected"
  end
end
