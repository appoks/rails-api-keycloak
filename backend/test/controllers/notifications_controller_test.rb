require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @notification = notifications(:one)
  end

  test "should get index" do
    get notifications_url, as: :json
    assert_response :success
  end

  test "should create notification" do
    assert_difference('Notification.count') do
      post notifications_url, params: { notification: { kind: @notification.kind, message: @notification.message, read: @notification.read } }, as: :json
    end

    assert_response 201
  end

  test "should show notification" do
    get notification_url(@notification), as: :json
    assert_response :success
  end

  test "should update notification" do
    patch notification_url(@notification), params: { notification: { kind: @notification.kind, message: @notification.message, read: @notification.read } }, as: :json
    assert_response 200
  end

  test "should destroy notification" do
    assert_difference('Notification.count', -1) do
      delete notification_url(@notification), as: :json
    end

    assert_response 204
  end
end
