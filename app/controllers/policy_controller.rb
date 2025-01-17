# frozen_string_literal: true

class DiscoursePolicy::PolicyController < ::ApplicationController
  requires_plugin DiscoursePolicy::PLUGIN_NAME

  before_action :ensure_logged_in, :set_post
  before_action :ensure_can_accept, only: [:accept, :unaccept]

  def accept
    PolicyUser.add!(current_user, @post.post_policy)
    @post.publish_change_to_clients!(:policy_change)

    render json: success_json
  end

  def unaccept
    PolicyUser.remove!(current_user, @post.post_policy)
    @post.publish_change_to_clients!(:policy_change)

    render json: success_json
  end

  def accepted
    users = @post
      .post_policy
      .accepted_by
      .offset(params[:offset])
      .limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)

    render json: {
      users: serialize_data(users, BasicUserSerializer)
    }
  end

  def not_accepted
    @post = Post.find(params[:post_id])
    users = @post
      .post_policy
      .not_accepted_by
      .offset(params[:offset])
      .limit(DiscoursePolicy::POLICY_USER_DEFAULT_LIMIT)

    render json: {
      users: serialize_data(users, BasicUserSerializer)
    }
  end

  private

  def ensure_can_accept
    if !GroupUser.where('group_id in (:group_ids) and user_id = :user_id', group_ids: @group_ids, user_id: current_user.id).exists?
      return render_json_error(I18n.t("discourse_policy.error.user_missing"))
    end

    true
  end

  def set_post
    if !SiteSetting.policy_enabled
      raise Discourse::NotFound
    end

    params.require(:post_id)
    @post = Post.find_by(id: params[:post_id])

    if !@post
      raise Discourse::NotFound
    end

    if !@post.post_policy
      return render_json_error(I18n.t("discourse_policy.errors.no_policy"))
    end

    @group_ids = @post.post_policy.groups.pluck(:id)

    if @group_ids.blank?
      return render_json_error(I18n.t("discourse_policy.error.group_not_found"))
    end

    if SiteSetting.policy_restrict_to_staff_posts && !@post.user&.staff?
      return render_json_error(I18n.t("discourse_policy.errors.staff_only"))
    end

    true
  end
end
