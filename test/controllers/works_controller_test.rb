require "test_helper"

describe WorksController do
  let(:existing_work) { works(:album) }

  describe "root" do
    describe "logged-in user" do
      before do
        perform_login
      end

      it "succeeds with all media types" do
        get root_path

        must_respond_with :success
      end

      it "succeeds with one media type absent" do
        only_book = works(:poodr)
        only_book.destroy

        get root_path

        must_respond_with :success
      end

      it "succeeds with no media" do
        Work.all do |work|
          work.destroy
        end

        get root_path

        must_respond_with :success
      end
    end
    describe "logged-out user" do
      it "succeeds with all media types" do
        get root_path

        must_respond_with :success
      end

      it "succeeds with one media type absent" do
        only_book = works(:poodr)
        only_book.destroy

        get root_path

        must_respond_with :success
      end

      it "succeeds with no media" do
        Work.all do |work|
          work.destroy
        end

        get root_path

        must_respond_with :success
      end
    end
  end

  CATEGORIES = %w(albums books movies)
  INVALID_CATEGORIES = ["nope", "42", "", "  ", "albumstrailingtext"]

  describe "index" do
    describe "logged-in user" do
      before do
        perform_login
      end
      it "succeeds when there are works" do
        get works_path

        must_respond_with :success
      end

      it "succeeds when there are no works" do
        Work.all do |work|
          work.destroy
        end

        get works_path

        must_respond_with :success
      end
    end

    describe "non-logged-in user" do
      it "redirects and flashes failure when there are works" do
        get works_path

        must_respond_with :redirect
        must_redirect_to root_path

        expect(flash[:status]).must_equal :failure
        expect(flash[:result_text]).must_equal "You must be logged in to see this page"
      end

      it "redirects and flashes failure when there are no works" do
        Work.all do |work|
          work.destroy
        end

        get works_path

        must_respond_with :redirect
        must_redirect_to root_path

        expect(flash[:status]).must_equal :failure
        expect(flash[:result_text]).must_equal "You must be logged in to see this page"
      end
    end
  end

  describe "new" do
    it "succeeds" do
      get new_work_path

      must_respond_with :success
    end
  end

  describe "create" do
    it "creates a work with valid data for a real category" do
      new_work = {work: {title: "Dirty Computer", category: "album"}}

      expect {
        post works_path, params: new_work
      }.must_change "Work.count", 1

      new_work_id = Work.find_by(title: "Dirty Computer").id

      must_respond_with :redirect
      must_redirect_to work_path(new_work_id)
    end

    it "renders bad_request and does not update the DB for bogus data" do
      bad_work = {work: {title: nil, category: "book"}}

      expect {
        post works_path, params: bad_work
      }.wont_change "Work.count"

      must_respond_with :bad_request
    end

    it "renders 400 bad_request for bogus categories" do
      INVALID_CATEGORIES.each do |category|
        invalid_work = {work: {title: "Invalid Work", category: category}}

        proc { post works_path, params: invalid_work }.wont_change "Work.count"

        Work.find_by(title: "Invalid Work", category: category).must_be_nil
        must_respond_with :bad_request
      end
    end
  end

  describe "show" do
    describe "logged-in user" do
      before do
        perform_login
      end
      it "succeeds for an extant work ID" do
        get work_path(existing_work.id)

        must_respond_with :success
      end

      it "renders 404 not_found for a bogus work ID" do
        destroyed_id = existing_work.id
        existing_work.destroy

        get work_path(destroyed_id)

        must_respond_with :not_found
      end
    end

    describe "non-logged-in user" do
      it "redirects and flashes failure for an extant work ID" do
        get work_path(existing_work.id)

        must_respond_with :redirect
        must_redirect_to root_path

        expect(flash[:status]).must_equal :failure
        expect(flash[:result_text]).must_equal "You must be logged in to see this page"
      end

      it "renders 404 not_found for a bogus work ID" do
        destroyed_id = existing_work.id
        existing_work.destroy

        get work_path(destroyed_id)

        must_respond_with :not_found
      end
    end
  end

  describe "edit" do
    it "succeeds for an extant work ID" do
      get edit_work_path(existing_work.id)

      must_respond_with :success
    end

    it "renders 404 not_found for a bogus work ID" do
      bogus_id = existing_work.id
      existing_work.destroy

      get edit_work_path(bogus_id)

      must_respond_with :not_found
    end
  end

  describe "update" do
    it "succeeds for valid data and an extant work ID" do
      updates = {work: {title: "Dirty Computer"}}

      expect {
        put work_path(existing_work), params: updates
      }.wont_change "Work.count"
      updated_work = Work.find_by(id: existing_work.id)

      updated_work.title.must_equal "Dirty Computer"
      must_respond_with :redirect
      must_redirect_to work_path(existing_work.id)
    end

    it "renders bad_request for bogus data" do
      updates = {work: {title: nil}}

      expect {
        put work_path(existing_work), params: updates
      }.wont_change "Work.count"

      work = Work.find_by(id: existing_work.id)

      must_respond_with :not_found
    end

    it "renders 404 not_found for a bogus work ID" do
      bogus_id = existing_work.id
      existing_work.destroy

      put work_path(bogus_id), params: {work: {title: "Test Title"}}

      must_respond_with :not_found
    end
  end

  describe "destroy" do
    it "succeeds for an extant work ID" do
      expect {
        delete work_path(existing_work.id)
      }.must_change "Work.count", -1

      must_respond_with :redirect
      must_redirect_to root_path
    end

    it "renders 404 not_found and does not update the DB for a bogus work ID" do
      bogus_id = existing_work.id
      existing_work.destroy

      expect {
        delete work_path(bogus_id)
      }.wont_change "Work.count"

      must_respond_with :not_found
    end
  end

  describe "upvote" do
    it "redirects to the work page if no user is logged in" do
      work = works(:poodr)
      vote_count = work.votes.length
      all_votes = Vote.all.length

      post upvote_path(work.id)
      must_respond_with :redirect
      must_redirect_to work_path(work.id)

      work.reload

      expect(work.votes.length).must_equal vote_count
      expect(Vote.all.length).must_equal all_votes
    end

    it "succeeds for a logged-in user and a fresh user-vote pair" do
      work = works(:poodr)
      user = users(:dan)

      work_vote_count = work.votes.length
      all_votes = Vote.all.length

      perform_login(user)

      expect(session[:user_id]).must_equal user.id

      post upvote_path(work.id)

      must_respond_with :redirect
      must_redirect_to work_path(work.id)
      expect(Vote.all.length).must_equal all_votes + 1

      work.reload

      # this works in production but not here
      expect(work.votes.length).must_equal work_vote_count + 1
    end

    it "redirects to the work page if the user has already voted for that work" do
      work = works(:poodr)
      user = users(:dan)

      perform_login(user)

      session[:user_id].must_equal user.id

      post upvote_path(work.id)
      work_vote_count = work.votes.length
      post upvote_path(work.id)

      must_respond_with :redirect
      must_redirect_to work_path(work.id)

      work.reload

      expect(work.votes.length).must_equal work_vote_count
    end

    it "flashes error and redirects if no user is logged in" do
      work = works(:poodr)

      work_vote_count = work.votes.length

      post upvote_path(work.id)

      must_respond_with :redirect
      must_redirect_to work_path(work.id)
      expect(flash[:status]).must_equal :failure
      expect(flash[:result_text]).must_equal "You must log in to do that"

      work.reload

      expect(work.votes.length).must_equal work_vote_count
    end
  end
end
